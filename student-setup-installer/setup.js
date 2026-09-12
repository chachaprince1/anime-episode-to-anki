const params=new URLSearchParams(location.search);
const dest=params.get('dest')||'the staged Extensions folder';
const anime=`${dest}/anime-episode-to-anki`, immersion=`${dest}/immersionkit-full-card-extension`;
for(const [id,value] of [['animePath',anime],['animePath2',anime],['immersionPath',immersion]])document.querySelector('#'+id).textContent=value;
const status=document.querySelector('#checkStatus');
const y=params.get('yomitan')==='ok',a=params.get('anki')==='ok';status.textContent=`Yomitan API (/serverVersion): ${y?'ONLINE':'OFFLINE'}\nAnkiConnect (version action): ${a?'ONLINE':'OFFLINE'}`;status.className=`status ${y&&a?'ok':'warn'}`;
