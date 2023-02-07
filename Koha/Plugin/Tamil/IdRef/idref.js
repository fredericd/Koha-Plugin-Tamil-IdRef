(function( jQuery, undefined ) {

// Configuration locales
let c;
let proxy;
let idAutorite = "";
let remoteClientExist = false;
let oFrame;
let idrefinit = false;

let kohaCloneField = window.CloneField;
window.CloneField = function(args) {
  const idPrev = arguments[0];
  kohaCloneField(args);

  c.catalog.fields_array.forEach(function(tag) {
    const divs = $(`[id^=div_indicator_tag_${tag}]`);
    for (let i=0; i < divs.length; i++) {
      (function(){
        const div = $(divs.get(i));
        const button = div.find('a.popupIdRef');
        button.click(function(e) { onClick(e, div); });
      })();
    }
  });
  
};

let current = {
  tag: '',
  id: '',
  set: (letter, value) => {
    const subid = current.id.substr(0, 6);
    $(`#tag_${current.tag}_${current.id} [id^=tag_${current.tag}_subfield_${letter}_${subid}]`).val(value)
  },
  get: (letter) => {
    const subid = current.id.substr(0, 6);
    return $(`#tag_${current.tag}_${current.id} [id^=tag_${current.tag}_subfield_${letter}_${subid}]`).val();
  }
};

const serializer = {
  stringify: function(data) {
    let message = "";
    for (let key in data) {
      if (data.hasOwnProperty(key)) {
        message += key + "=" + escape(data[key]) + "&";
      }
    }
    return message.substring(0, message.length - 1);
  },
  parse: function(message) {
    const data = {};
    let d = message.split("&");
    let pair, key, value;
    for (let i = 0, len = d.length; i < len; i++) {
      pair = d[i];
      key = pair.substring(0, pair.indexOf("="));
      value = pair.substring(key.length + 1);
      data[key] = unescape(value);
    }
    return data;
  }
};


function initClient() {

  // Rend la fenêtre déplaçable
  $("#popupContainer").draggable();

  if (remoteClientExist) {
    showPopWin("", screen.width*0.7, screen.height*0.6, null);
    return 0;
  }

  showPopWin("", screen.width*0.7, screen.height*0.6, null);
  remoteClientExist = true;
  if (document.addEventListener) {
    window.addEventListener("message", function(e) {
      traiteResultat(e);
    });
  }
  else {
    window.attachEvent('onmessage', function(e) {
      traiteResultat(e);
    });
  }
  return 0;
}

function escapeHtml(texte) {
  return texte
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function parseMarcHeading(xml) {
  let pos = xml.indexOf('<datafield tag="2');
  if (pos === -1) return;

  xml = xml.substring(pos+40);
  pos = xml.indexOf('</datafield>');
  xml = xml.substring(0, pos-3);
  const lines = xml.split("\n");
  const field = {};
  lines.forEach((line) => {
    const letter = line.substr(20, 1);
    let value = line.substr(23);
    value = value.substr(0, value.length-11);
    field[letter] = value;
  });
  return field;
}

function traiteResultat(e) {
  let data = e.data;
  data = serializer.parse(data);

  const ppn = data.b;
  if (ppn === undefined) return;
  current.set('3', ppn);
  
  const field = parseMarcHeading(data.f);
  ['a','b','c','d','e','f','g','h','p'].forEach((letter) => {
    const value = field[letter] || '';
    if (value) current.set(letter, value);
  });

  hidePopWin(null);
}


function onClick(e, div) {
  const idtop = div.attr('id');
  const tag = idtop.substr(18, 3);
  current.tag = tag;
  current.id = idtop.substr(22);
  
  let index = 'Nom de personne';
  if (tag == '601' || tag == '710' || tag == '711' || tag == '712' ) index = 'Nom de collectivité';
  let value = current.get('3');
  if (value) {
    index = 'Identifiant IdRef (n°PPN)';
  } else {
    value = current.get('a') + ' ' + current.get('b');
    value = value.replace(/'/g, "\\\'");
  }


  const { idclient } = c.idref;
  let ymd = new Date().toISOString().split('T')[0].replace(/-/g, '');
  const message = {
    Index1: index,
    Index1Value: value,
    fromApp: idclient,
    'z686_a': idclient,
    'z686_c': idclient,
    'z686_2': ymd,
  };

  let auttag =
    (tag == '710' || tag == '711' || tag == '712') ? '210' :
    '200'
  message[`z${auttag}_a`] = current.get('a');
  message[`z${auttag}_b`] = current.get('b');
  message[`z${auttag}_f`] = current.get('f');

  // 200$a : 200$e / 200$f, 200$g, 210 $d
  const racine = '[id^=tag_200_subfield_';
  let title = [];
  const append = (where, prefix) => {
    const v = value = $(where).val();
    if (v) {
      if (prefix) title.push(prefix);
      title.push(v);
    }
  };
  append('[id^=tag_200_subfield_a');
  append('[id^=tag_200_subfield_e', ' e ');
  append('[id^=tag_200_subfield_f', ' / ');
  append('[id^=tag_200_subfield_g', ' / ');
  append('[id^=tag_214_subfield_d', ', ');
  append('[id^=tag_210_subfield_d', ', ');
  message.z810_a = 'Auteur de : ' + title.join('');

  let lang = $('[id^=tag_100_subfield_a_').val();
  lang = lang.substr(22,3);
  message.z101_a = lang;
  //console.log(message);

  if (initClient()==0) {};

  oFrame = document.getElementById("popupFrame");
  if (!idrefinit) {
    oFrame.contentWindow.postMessage(serializer.stringify({Init:"true"}), "*");
    idrefinit = false;
  }

  oFrame.contentWindow.postMessage(serializer.stringify(message), "*");

  e.preventDefault();
}


function pageCatalog() {
  // On charge les éléments externes
  $('head').append('<link rel="stylesheet" type="text/css" href="/plugin/Koha/Plugin/Tamil/IdRef/subModal.css">');
  $.getScript("/plugin/Koha/Plugin/Tamil/IdRef/subModal.js")
   .done(() => {
     console.log(c.idref.url);
     gDefaultPage = c.idref.url;
   });
  c.catalog.fields_array.forEach(function(tag) {
    //console.log(`tag: ${tag}`);
    const divs = $(`[id^=div_indicator_tag_${tag}]`);
    //console.log('div length: ' + divs.length);
    for (let i=0; i < divs.length; i++) {
      (function(){
        //console.log(i);
        const div = $(divs.get(i));
        //console.log(div);
        const button = $("<a href='#' class='popupIdRef'><img src='/plugin/Koha/Plugin/Tamil/IdRef/img/idref-short.svg' style='max-height: 24px;'/></a>");
        div.append(button);
        button.click((e) => onClick(e, div));
      })();
    }
  });
}




function run(conf) {
  c = conf;
  if (c.catalog.enabled && $('body').is("#cat_addbiblio")) {
    pageCatalog();
  }
}

$.extend({
  tamilIdRef: (c) => run(c),
});


})( jQuery );
