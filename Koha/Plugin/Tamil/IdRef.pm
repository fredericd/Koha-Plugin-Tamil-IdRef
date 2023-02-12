package Koha::Plugin::Tamil::IdRef;

use Modern::Perl;
use utf8;
use base qw(Koha::Plugins::Base);
use CGI qw(-utf8);
use C4::Context;
use C4::Biblio;
use Koha::Cache;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Template;
use Encode qw/ decode /;
use MARC::Moose::Record;
use YAML;
use JSON qw/ to_json /;
use Try::Tiny;


## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Tamil IdRef',
    description     => 'Catalogage avec IdRef',
    author          => 'Tamil s.a.r.l.',
    date_authored   => '2021-10-15',
    date_updated    => "2023-02-11",
    minimum_version => '17.05.00.000',
    maximum_version => undef,
    copyright       => '2023',
    version         => '1.0.2',
};


my $conf = {

};


sub new {
    my ($class, $args) = @_;

    $args->{metadata} = $metadata;
    $args->{metadata}->{class} = $class;
    $args->{cache} = Koha::Cache->new();

    $class->SUPER::new($args);
}

sub config {
    my $self = shift;

    my $c = $self->{args}->{c};
    unless ($c) {
        $c = $self->retrieve_data('c');
        if ($c) {
            utf8::encode($c);
            $c = decode_json($c);
        }
        else {
            $c = {};
        }
    }
    $c->{idref} ||= {};
    $c->{idref}->{url} ||= 'https://www.idref.fr';
    $c->{idref}->{idclient} ||= 'tamil';
    $c->{metadata} = $self->{metadata};

    my @fields = split /\r|\n/, $c->{catalog}->{fields};
    @fields = grep { $_ } @fields;
    $c->{catalog}->{fields_array} = \@fields;

    $self->{args}->{c} = $c;

    return $c;
}

sub get_form_config {
    my $cgi = shift;
    my $c = {
        idref => {
            url => undef,
            idclient => undef,
        },
        catalog => {
            enabled => 0,
            fields => 0,
        },
    };

    my $set;
    $set = sub {
        my ($node, $path) = @_;
        return if ref($node) ne 'HASH';
        for my $subkey ( keys %$node ) {
            my $key = $path ? "$path.$subkey" : $subkey;
            my $subnode = $node->{$subkey};
            if ( ref($subnode) eq 'HASH' ) {
                $set->($subnode, $key);
            }
            else {
                $node->{$subkey} = $cgi->param($key);
            }
        }
    };

    $set->($c);
    return $c;
}

sub configure {
    my ($self, $args) = @_;
    my $cgi = $self->{'cgi'};

    if ( $cgi->param('save') ) {
        my $c = get_form_config($cgi);
        my $rcr = [
            map { s/'/''/g }
            split /\n/, $c->{catalog}->{fields}
        ];
        $self->store_data({ c => encode_json($c) });
        print $self->{'cgi'}->redirect(
            "/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::Tamil::IdRef&method=tool");
    }
    else {
        my $template = $self->get_template({ file => 'configure.tt' });
        $template->param( c => $self->config() );
        $self->output_html( $template->output() );
    }
}

sub tool {
    my ($self, $args) = @_;

    my $cgi = $self->{cgi};

    my $template;
    my $c = $self->config();
    my $ws = $cgi->param('ws');
    if ( $ws ) {
        if ($ws eq 'realign') {
            $template = $self->get_template({ file => 'realign.tt' });
            my $table = $self->get_qualified_table_name('action');
            my $actions = C4::Context->dbh->selectall_arrayref(qq{
                SELECT id, start, end FROM $table
                WHERE type = 'realign'
                ORDER BY start DESC
            }, { Slice => {} });
            $template->param( actions => $actions );
        }
        elsif ($ws eq 'realignid') {   
            $template = $self->get_template({ file => 'realignid.tt' });
            $template->param( c => $c );
            my $table = $self->get_qualified_table_name('action');
            my $id = $cgi->param('id');
            my $action = C4::Context->dbh->selectall_arrayref(qq{
                SELECT * FROM $table
                WHERE type = 'realign'
                AND id=$id
            }, { Slice => {} });
            my $realign;
            if ($action) {
                $action = $action->[0];
                $realign = $action->{result};
                $realign = decode_json($realign);
            }
            my @realign;
            for my $biblionumber (keys %$realign ) {
                for my $action ( @{$realign->{$biblionumber}} ) {
                    $action->{bn} = $biblionumber;
                    push @realign, $action;
                }
            }
            $template->param( realign => \@realign, action => $action );
        }
    }
    else {
        $template = $self->get_template({ file => 'home.tt' });
    }
    $template->param( c => $self->config() );
    $template->param( WS => $ws ) if $ws;
    $self->output_html( $template->output() );
}

sub intranet_js {
    my $self = shift;
    my $js_file = $self->get_plugin_http_path() . "/idref.js";
    my $c = to_json($self->config());
    return <<EOS;
<script>
\$(document).ready(() => {
    \$.getScript("$js_file")
        .done(() => \$.tamilIdRef($c));
    });
</script>
EOS

}

sub install() {
    my ($self, $args) = @_;

    my $dbh = C4::Context->dbh;
    my $name = $self->get_qualified_table_name('action');
    $dbh->do("DROP TABLE IF EXISTS $name");
    $dbh->do(qq{
        CREATE TABLE $name (
            id SERIAL,
            type VARCHAR(80),
            result JSON,
            start TIMESTAMP NULL,
            end TIMESTAMP NULL,
            PRIMARY KEY (id),
            INDEX (type)
        )
    });
}

sub upgrade {
    my ($self, $args) = @_;

    my $dt = DateTime->now();
    $self->store_data( { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

    return 1;
}

sub uninstall() {
    my ($self, $args) = @_;

    my $dbh = C4::Context->dbh;
    my $name = $self->get_qualified_table_name('action');
    $dbh->do("DROP TABLE IF EXISTS $name");
}


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

    my $start = DateTime->now;

    my $plugin = Koha::Plugin::Tamil::IdRef->new({
        enable_plugins => 1,
    });

    my $cache = $self->{cache};

    my ($biblionumber, $record);
    my $sth = C4::Context->dbh->prepare(
        "SELECT biblionumber FROM biblio_metadata
         WHERE biblionumber BETWEEN $from AND $to");
    $sth->execute();
    
    my $ua  = Mojo::UserAgent->new;
    my $actions = {};
    while ( ($biblionumber) = $sth->fetchrow ) {
        say $biblionumber;
        $record = GetMarcBiblio({ biblionumber => $biblionumber });
        next unless $record;
        $record = MARC::Moose::Record::new_from($record, 'Legacy');
        my $modified = 0;
        FIELDS_LOOP:
        for my $field ( $record->field('7..|600|601') ) {
            my $ppn = $field->subfield('3');
            next unless $ppn;
            my $xml = $cache->get_from_cache($ppn);
            say "PPN $ppn" if $xml;
            my ($url, $res, $action, $new_ppn);
            unless ($xml) {
                $url = "https://www.idref.fr/$ppn.xml";
                $res = $ua->get($url)->result;
            }
            #say Dump($res);
            if ($xml || $res->is_success || $res->code eq '301') {
                if (!$xml && $res->code eq '301') {
                    # PPN fusionné à un autre PPN
                    $xml = undef;
                    $url = $res->headers->location;
                    $url =~ /\.fr\/(.+)\.xml$/;
                    $new_ppn = $1;
                    $res = $ua->get($url)->result;
                }
                next if !$xml && $res->headers->content_type !~ /xml/;
                unless ($xml) {
                    $xml = $res->body;
                    $cache->set_in_cache($ppn, $xml, { expiry => 5184000 });
                }
                my $auth = MARC::Moose::Record::new_from($xml, 'marcxml');
                if ($new_ppn) {
                    $action = {
                        action => 'merge',
                        ppn => $ppn,
                        avant => $field->as_formatted,
                    };
                    for (@{$field->subf}) {
                        $_->[1] = $new_ppn if $_->[0] eq '3';
                    }
                    $action->{apres} = $field->as_formatted;
                    push @{$actions->{$biblionumber}}, $action;
                    $action = undef;
                }
                my $field_match = join(' ',
                    map { $_->[1] } grep { $_->[0] =~ /[abcf]/ } @{$field->subf});
                # Récupération de la vedette, en écriture latine (frefre en $8)
                my @heading = $auth->field('2..');
                my $heading;
                if (@heading > 1) {
                    for my $field (@heading) {
                        my $lang = $field->subfield('8') || '';
                        $heading = $field if $lang eq 'frefre';
                    }
                }
                $heading = $heading[0] unless $heading;
                unless ($heading) {
                    say "PAS DE VEDETTE :";
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
                        ppn => $new_ppn || $ppn,
                        avant => $field->as_formatted,
                    };
                    my @subf = grep { $_->[0] !~ /[abcf]/ } @{$field->subf};
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
                $field->subf( [ grep { $_->[0] !~ '3' } @{$field->subf} ] );
                $action->{apres} = $field->as_formatted;
                $modified = 1;
            }
            if ($action) {
                push @{$actions->{$biblionumber}}, $action;
                $modified = 1;
            }
        }
        next unless $modified;
    }
    #say Dump($actions);
    #exit;

    my $table_name = $self->get_qualified_table_name('action');
    C4::Context->dbh->do(qq{
        INSERT INTO $table_name (type, result, start, end)
        VALUES (?, ?, ?, ?)
    }, undef, 'realign', to_json($actions), $start, DateTime->now );
}


1;
