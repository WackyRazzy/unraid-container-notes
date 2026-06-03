#!/bin/bash
# ============================================================
#  Container Notes Plugin â€” Installer
#  Run this once in the Unraid terminal.
#  It installs all plugin files and survives reboots.
# ============================================================

PLUGIN_DIR="/usr/local/emhttp/plugins/container-notes"
BOOT_DIR="/boot/config/plugins/container-notes"

echo ""
echo "=== Container Notes Plugin Installer ==="
echo ""

mkdir -p "$PLUGIN_DIR"
mkdir -p "$BOOT_DIR"

echo "â†’ Writing notes_api.php..."
cat > "$PLUGIN_DIR/notes_api.php" << 'PHPEOF'
<?php
$notesDir  = '/boot/config/plugins/container-notes';
$notesFile = $notesDir . '/notes.json';
if (!is_dir($notesDir)) mkdir($notesDir, 0755, true);
header('Content-Type: application/json');
$method = $_SERVER['REQUEST_METHOD'];
if ($method === 'GET') {
    echo file_exists($notesFile) ? file_get_contents($notesFile) : json_encode((object)[]);
    exit;
}
if ($method === 'POST') {
    $body = json_decode(file_get_contents('php://input'), true);
    if (!isset($body['container']) || !isset($body['note'])) {
        http_response_code(400); echo json_encode(['error'=>'bad input']); exit;
    }
    $notes = file_exists($notesFile) ? (json_decode(file_get_contents($notesFile), true) ?: []) : [];
    $note  = trim($body['note']);
    if ($note === '') unset($notes[trim($body['container'])]);
    else $notes[trim($body['container'])] = $note;
    file_put_contents($notesFile, json_encode($notes, JSON_PRETTY_PRINT));
    echo json_encode(['ok' => true]);
    exit;
}
http_response_code(405);
echo json_encode(['error' => 'method not allowed']);
PHPEOF

echo "â†’ Writing container-notes.js..."
cat > "$PLUGIN_DIR/container-notes.js" << 'JSEOF'
(function(){
  'use strict';
  const API='/plugins/container-notes/notes_api.php';
  let notesCache={};
  const CSS=`
    .cn-row > td { padding:2px 8px 3px 16px !important; border-top:1px solid var(--border-color) !important; background:var(--gray-150) !important; }
    .cn-wrap { display:flex; align-items:center; gap:6px; min-height:20px; }
    .cn-pencil { cursor:pointer; font-size:13px; color:var(--gray-400); flex-shrink:0; user-select:none; line-height:1; transition:color 0.15s; }
    .cn-pencil:hover { color:var(--orange-200); }
    .cn-pencil.active { color:var(--orange-300); }
    .cn-display { font-size:11.5px; color:var(--gray-400); font-style:italic; flex:1; cursor:pointer; white-space:pre-wrap; word-break:break-word; line-height:1.4; }
    .cn-display.has-note { color:var(--black); font-style:normal; font-weight:500; }
    .cn-editor { display:flex; align-items:flex-end; flex:1; gap:4px; }
    .cn-ta { flex:1; background:var(--gray-100); border:1px solid var(--border-color); border-radius:3px; color:var(--black); font-size:11.5px; padding:2px 6px; resize:none; min-height:24px; max-height:100px; font-family:inherit; line-height:1.4; outline:none; overflow:hidden; box-sizing:border-box; }
    .cn-ta:focus { border-color:var(--gray-500); background:var(--gray-000); }
    .cn-save { font-size:11px; padding:2px 10px; border-radius:3px; border:none; cursor:pointer; background:#4a90d9; color:#fff; flex-shrink:0; line-height:1.7; }
    .cn-save:hover { background:#3a7bc8; }
    .cn-cancel { font-size:11px; padding:2px 10px; border-radius:3px; border:1px solid var(--border-color); cursor:pointer; background:var(--gray-100); color:var(--gray-600); flex-shrink:0; line-height:1.7; }
    .cn-cancel:hover { background:var(--gray-200); }
  `;
  function injectStyles(){if(document.getElementById('cn-css'))return;const s=document.createElement('style');s.id='cn-css';s.textContent=CSS;document.head.appendChild(s);}
  async function loadNotes(){try{const r=await fetch(API,{cache:'no-store'});notesCache=await r.json();}catch(e){try{notesCache=JSON.parse(sessionStorage.getItem('cn')||'{}');}catch(_){}}sessionStorage.setItem('cn',JSON.stringify(notesCache));}
  async function saveNote(name,text){if(text)notesCache[name]=text;else delete notesCache[name];sessionStorage.setItem('cn',JSON.stringify(notesCache));try{await fetch(API,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({container:name,note:text})});}catch(e){console.warn('[ContainerNotes] save failed',e);}}
  function isFolderHeader(tr){return tr.classList.contains('sortable')&&/\bfolder\b/.test(tr.className)&&!tr.classList.contains('folder-element');}
  function isContainerRow(tr){return tr.classList.contains('sortable')&&!isFolderHeader(tr)&&!!tr.querySelector('td.ct-name');}
  function getNameFromRow(tr){const a=tr.querySelector('span.appname');if(a){const l=a.querySelector('a.exec');return(l?l.textContent:a.textContent).trim()||null;}const tds=tr.querySelectorAll('td');for(const td of tds){const t=td.textContent.trim();if(t&&t.length<60&&!t.match(/^\d+\/\d+/))return'folder:'+t.split('\n')[0].trim();}return null;}
  function buildNoteRow(key){
    const tr=document.createElement('tr');tr.className='cn-row';tr.dataset.cnFor=key;
    const td=document.createElement('td');td.colSpan=99;
    const wrap=document.createElement('div');wrap.className='cn-wrap';
    const pencil=document.createElement('span');pencil.className='cn-pencil';pencil.textContent='\u270e';pencil.title='Click to add/edit note';
    const display=document.createElement('span');display.className='cn-display';
    const note=notesCache[key]||'';
    if(note){display.textContent=note;display.classList.add('has-note');pencil.classList.add('active');}else{display.textContent='Add a note\u2026';}
    function openEditor(){
      if(wrap.querySelector('.cn-editor'))return;
      display.style.display='none';pencil.style.display='none';
      const editor=document.createElement('div');editor.className='cn-editor';
      const ta=document.createElement('textarea');ta.className='cn-ta';ta.rows=1;ta.value=notesCache[key]||'';ta.placeholder='Add a note\u2026 (Ctrl+Enter saves, Esc cancels)';
      const save=document.createElement('button');save.className='cn-save';save.textContent='Save';
      const cancel=document.createElement('button');cancel.className='cn-cancel';cancel.textContent='Cancel';
      editor.appendChild(ta);editor.appendChild(save);editor.appendChild(cancel);wrap.appendChild(editor);
      function resize(){ta.style.height='auto';ta.style.height=Math.min(ta.scrollHeight,100)+'px';}
      ta.addEventListener('input',resize);
      setTimeout(()=>{resize();ta.focus();ta.setSelectionRange(ta.value.length,ta.value.length);},10);
      save.addEventListener('click',async()=>{const val=ta.value.trim();await saveNote(key,val);closeEditor(val);});
      cancel.addEventListener('click',()=>closeEditor(notesCache[key]||''));
      ta.addEventListener('keydown',e=>{if(e.key==='Enter'&&(e.ctrlKey||e.metaKey))save.click();if(e.key==='Escape')cancel.click();});
    }
    function closeEditor(f){const ed=wrap.querySelector('.cn-editor');if(ed)ed.remove();display.style.display='';pencil.style.display='';if(f){display.textContent=f;display.classList.add('has-note');pencil.classList.add('active');}else{display.textContent='Add a note\u2026';display.classList.remove('has-note');pencil.classList.remove('active');}}
    pencil.addEventListener('click',openEditor);display.addEventListener('click',openEditor);
    wrap.appendChild(pencil);wrap.appendChild(display);td.appendChild(wrap);tr.appendChild(td);return tr;
  }
  function injectAll(){document.querySelectorAll('tr.sortable').forEach(tr=>{if(tr.classList.contains('cn-row')||tr.classList.contains('folder-element'))return;if(!isFolderHeader(tr)&&!isContainerRow(tr))return;const next=tr.nextElementSibling;if(next&&next.classList.contains('cn-row'))return;const name=getNameFromRow(tr);if(!name)return;tr.parentNode.insertBefore(buildNoteRow(name),tr.nextSibling);});}
  function watch(){let timer=null;const obs=new MutationObserver(muts=>{const relevant=muts.some(m=>[...m.addedNodes].some(n=>n.nodeType===1&&!n.classList?.contains('cn-row')&&(n.tagName==='TR'||n.tagName==='TBODY'||n.querySelector?.('tr.sortable'))));if(relevant){clearTimeout(timer);timer=setTimeout(injectAll,250);}});obs.observe(document.body,{childList:true,subtree:true});}
  async function init(){if(window.location.pathname!=='/Docker')return;injectStyles();await loadNotes();injectAll();watch();}
  if(document.readyState==='loading'){document.addEventListener('DOMContentLoaded',init);}else{init();}
})();
JSEOF

echo "â†’ Writing container-notes.page..."
cat > "$PLUGIN_DIR/container-notes.page" << 'PAGEEOF'
Menu="Docker"
Icon="sticky-note"
---
<script src="/plugins/container-notes/container-notes.js"></script>
PAGEEOF

echo "â†’ Writing boot-restore script..."
cat > "$BOOT_DIR/restore.sh" << 'RESTOREEOF'
#!/bin/bash
PLUGIN_DIR="/usr/local/emhttp/plugins/container-notes"
BOOT_DIR="/boot/config/plugins/container-notes"
mkdir -p "$PLUGIN_DIR"
for f in notes_api.php container-notes.js container-notes.page; do
  [ -f "$BOOT_DIR/$f" ] && cp "$BOOT_DIR/$f" "$PLUGIN_DIR/$f"
done
RESTOREEOF
chmod +x "$BOOT_DIR/restore.sh"

echo "â†’ Backing up to /boot..."
cp "$PLUGIN_DIR/notes_api.php"         "$BOOT_DIR/notes_api.php"
cp "$PLUGIN_DIR/container-notes.js"   "$BOOT_DIR/container-notes.js"
cp "$PLUGIN_DIR/container-notes.page" "$BOOT_DIR/container-notes.page"

GO_FILE="/boot/config/go"
if grep -qF "container-notes/restore.sh" "$GO_FILE" 2>/dev/null; then
  echo "â†’ Boot hook already present."
else
  echo "â†’ Adding boot hook to $GO_FILE..."
  printf '\n# Container Notes Plugin\nbash /boot/config/plugins/container-notes/restore.sh\n' >> "$GO_FILE"
fi

cat > "$BOOT_DIR/uninstall.sh" << 'UNEOF'
#!/bin/bash
rm -rf /usr/local/emhttp/plugins/container-notes
sed -i '/container-notes\/restore\.sh/d' /boot/config/go
sed -i '/Container Notes Plugin/d' /boot/config/go
echo "Done. Notes data kept at /boot/config/plugins/container-notes/notes.json"
UNEOF
chmod +x "$BOOT_DIR/uninstall.sh"

echo ""
echo "âœ“ Done!"
echo "  1. Hard-refresh Docker page: Ctrl+Shift+R"
echo "  2. Each container and folder will have an 'Add a note...' row"
echo "  3. Click âœŽ or the text to type a note, Ctrl+Enter to save"
echo ""
