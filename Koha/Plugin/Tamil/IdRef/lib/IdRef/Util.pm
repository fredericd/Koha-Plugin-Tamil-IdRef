package IdRef::Util;

use Modern::Perl;
use base qw(Koha::Plugin::Tamil::IdRef);
use Koha::Plugin::Tamil::IdRef;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use C4::Context;
use C4::Biblio;
use MARC::Moose::Record;
use YAML qw/ Dump /;
use JSON qw/ to_json /;


sub realign {
    my $self = shift;

    my ($from, $to, $doit) = (1, 999999999, 0);
    while (@_) {
        $_ = shift;
        if    ( /^[0-9]*$/ )            { $from = $to = $_;        }
        elsif ( /^([0-9]+)-$/ )         { $from = $1;              }
        elsif ( /^-([0-9]+)$/ )         { $to = $1;                }
        elsif ( /^([0-9]+)-([0-9]+)$/ ) { ($from, $to) = ($1, $2); }
        elsif ( /doit/i )               {  $doit = 1;              }
    }
    say "from: $from - to: $to";

    my $plugin = Koha::Plugin::Tamil::IdRef->new({
        enable_plugins => 1,
    });

    my ($biblionumber, $record);
    my $sth = C4::Context->dbh->prepare(
        "SELECT biblionumber FROM biblio_metadata
         WHERE biblionumber BETWEEN $from AND $to");
    $sth->execute();
    
    my $ua  = Mojo::UserAgent->new;
    my $actions = {};
    while ( ($biblionumber) = $sth->fetchrow ) {
        $record = GetMarcBiblio({ biblionumber => $biblionumber });
        next unless $record;
        $record = MARC::Moose::Record::new_from($record, 'Legacy');
        my $modified = 0;
        for my $field ( $record->field('7..') ) {
            my $ppn = $field->subfield('3');
            next unless $ppn;
            my $url = "https://www.idref.fr/$ppn.xml";
            my $res = $ua->get($url)->result;
            my $action;
            if ($res->is_success) {
                my $xml = $res->body;
                my $auth = MARC::Moose::Record::new_from($xml, 'marcxml');
                #print $auth->as('text');
                my $auth_id = $auth->field('001')->value;
                if ($auth_id ne $ppn) {
                    say "DIFF";
                    say $record->as('text');
                    exit;
                }
                my $field_match = join(' ',
                    map { $_->[1] } grep { $_->[0] =~ /[abcf]/ } @{$field->subf});
                my $heading = $auth->field('2..');
                unless ($heading) {
                    say $auth->as('text');
                    exit;
                }
                my $heading_match = join(' ',
                    map { $_->[1] } grep { $_->[0] =~ /[abcf]/ }  @{$heading->subf} );
                if ($field_match ne $heading_match) {
                    #say $field->as_formatted;
                    #say $heading->as_formatted;
                    $action = {
                        action => 'modify',
                        ppn => $ppn,
                        avant => $field->as_formatted,
                    };
                    my @subf = grep { $_->[0] !~ /[abcf9]/ } @{$field->subf};
                    for (@{$heading->subf}) {
                        next if $_->[0] !~ /[abcf]/;
                        push @subf, $_;
                    }
                    $field->subf( \@subf );
                    $action->{apres} = $field->as_formatted;
                }
            }
            else {
                # $3 supprimé => ne pas le garder dans la notice...
                $action = {
                    action => 'del',
                    ppn => $ppn,
                    avant => $field->as_formatted,
                };
                $field->subf( [ grep { $_->[0] !~ '3|9' } @{$field->subf} ] );
                $action->{apres} = $field->as_formatted;
                $modified = 1;
            }
            if ($action) {
                push @{$actions->{$biblionumber}}, $action;
                $modified = 1;
            }
        }
        next unless $modified;
        #$print_rec->();
    }
    say to_json($actions, {pretty => 1});
}


sub sync {
    say "sync...";

    my $ua  = Mojo::UserAgent->new;
    my $url = "https://www.idref.fr/Sru/Solr";
    $url = "$url?wt=xml&version=2.2&start=&rows=3000&indent=on&fl=ppn_z,dateetat_dt&wt=json&q=dateetat_dt:[NOW-100DAY%20TO%20NOW]";
    my $res = $ua->get($url)->result;
    my $ppn;
    for (split /\n/, $res->body) {
        next unless /"ppn_z">(.*)</;
        push @$ppn, $1;
    }

    my $max = @$ppn;
    my $SLOT = 100;
    for (my $i = 0; $i < $max; $i += $SLOT) {
        my @inv;
        for (my $j = 0; $j < $SLOT; $j++) {
            my $index = $i + $j;
            last if $index == $max;
            push @inv, $ppn->[$index];
        }
        $url = 'https://www.idref.fr/services/merged_inv/' .
            join(',', @inv) . '&format=text/json';
        $res = $ua->get($url)->result;
        my $json = $res->json;
        say Dump($json);
    }
}

1;