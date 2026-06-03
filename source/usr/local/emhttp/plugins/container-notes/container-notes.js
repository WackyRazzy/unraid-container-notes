(function () {
  'use strict';

  const API = '/plugins/container-notes/notes_api.php';
  let notesCache = {};

  // ── CSS — uses Unraid's CSS variables, works on all themes ────────────────
  const CSS = `
    .cn-row > td {
      padding: 2px 8px 3px 16px !important;
      border-top: 1px solid var(--border-color) !important;
      background: var(--gray-150) !important;
    }
    .cn-wrap {
      display: flex;
      align-items: center;
      gap: 6px;
      min-height: 20px;
    }
    .cn-pencil {
      cursor: pointer;
      font-size: 13px;
      color: var(--gray-400);
      flex-shrink: 0;
      user-select: none;
      line-height: 1;
      transition: color 0.15s;
    }
    .cn-pencil:hover { color: var(--orange-200); }
    .cn-pencil.active { color: var(--orange-300); }
    .cn-display {
      font-size: 11.5px;
      color: var(--gray-400);
      font-style: italic;
      flex: 1;
      cursor: pointer;
      white-space: pre-wrap;
      word-break: break-word;
      line-height: 1.4;
    }
    .cn-display.has-note {
      color: var(--black);
      font-style: normal;
      font-weight: 500;
    }
    .cn-editor {
      display: flex;
      align-items: flex-end;
      flex: 1;
      gap: 4px;
    }
    .cn-ta {
      flex: 1;
      background: var(--gray-100);
      border: 1px solid var(--border-color);
      border-radius: 3px;
      color: var(--black);
      font-size: 11.5px;
      padding: 2px 6px;
      resize: none;
      min-height: 24px;
      max-height: 100px;
      font-family: inherit;
      line-height: 1.4;
      outline: none;
      overflow: hidden;
      box-sizing: border-box;
    }
    .cn-ta:focus { border-color: var(--gray-500); background: var(--gray-000); }
    .cn-save {
      font-size: 11px; padding: 2px 10px; border-radius: 3px;
      border: none; cursor: pointer;
      background: #4a90d9; color: #fff;
      flex-shrink: 0; line-height: 1.7;
    }
    .cn-save:hover { background: #3a7bc8; }
    .cn-cancel {
      font-size: 11px; padding: 2px 10px; border-radius: 3px;
      border: 1px solid var(--border-color); cursor: pointer;
      background: var(--gray-100); color: var(--gray-600);
      flex-shrink: 0; line-height: 1.7;
    }
    .cn-cancel:hover { background: var(--gray-200); }
  `;

  function injectStyles() {
    if (document.getElementById('cn-css')) return;
    const s = document.createElement('style');
    s.id = 'cn-css';
    s.textContent = CSS;
    document.head.appendChild(s);
  }

  // ── API ────────────────────────────────────────────────────────────────────
  async function loadNotes() {
    try {
      const r = await fetch(API, { cache: 'no-store' });
      notesCache = await r.json();
    } catch(e) {
      try { notesCache = JSON.parse(sessionStorage.getItem('cn') || '{}'); } catch(_){}
    }
    sessionStorage.setItem('cn', JSON.stringify(notesCache));
  }

  async function saveNote(name, text) {
    if (text) notesCache[name] = text; else delete notesCache[name];
    sessionStorage.setItem('cn', JSON.stringify(notesCache));
    try {
      await fetch(API, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': window.csrf_token || '' },
        body: JSON.stringify({ container: name, note: text })
      });
    } catch(e) { console.warn('[ContainerNotes] save failed', e); }
  }

  // ── Row classification ─────────────────────────────────────────────────────
  // FolderView2 folder HEADER rows:  class includes "sortable" AND "folder"
  // Individual container rows:       class includes "sortable" but NOT "folder"
  //
  // Both get note rows. The key is getting the right name from each.

  function isFolderHeader(tr) {
    return tr.classList.contains('sortable') && /\bfolder\b/.test(tr.className) && !tr.classList.contains('folder-element');
  }

  function isContainerRow(tr) {
    return tr.classList.contains('sortable') && !isFolderHeader(tr) && !!tr.querySelector('td.ct-name');
  }

  function getNameFromRow(tr) {
    // Individual container row
    const appname = tr.querySelector('span.appname');
    if (appname) {
      const a = appname.querySelector('a.exec');
      return (a ? a.textContent : appname.textContent).trim() || null;
    }
    // Folder header row — use the visible folder name text
    // Folder name is usually in a td with class containing the folder name text
    // It's the first text content that looks like a folder label
    const tds = tr.querySelectorAll('td');
    for (const td of tds) {
      const text = td.textContent.trim();
      if (text && text.length < 60 && !text.match(/^\d+\/\d+/)) {
        return 'folder:' + text.split('\n')[0].trim();
      }
    }
    return null;
  }

  // ── Build a note row ───────────────────────────────────────────────────────
  function buildNoteRow(key) {
    const tr = document.createElement('tr');
    tr.className = 'cn-row';
    tr.dataset.cnFor = key;

    const td = document.createElement('td');
    td.colSpan = 99;

    const wrap = document.createElement('div');
    wrap.className = 'cn-wrap';

    const pencil = document.createElement('span');
    pencil.className = 'cn-pencil';
    pencil.textContent = '✎';
    pencil.title = 'Click to add/edit note';

    const display = document.createElement('span');
    display.className = 'cn-display';

    const note = notesCache[key] || '';
    if (note) {
      display.textContent = note;
      display.classList.add('has-note');
      pencil.classList.add('active');
    } else {
      display.textContent = 'Add a note…';
    }

    function openEditor() {
      if (wrap.querySelector('.cn-editor')) return;
      display.style.display = 'none';
      pencil.style.display = 'none';

      const editor = document.createElement('div');
      editor.className = 'cn-editor';

      const ta = document.createElement('textarea');
      ta.className = 'cn-ta';
      ta.rows = 1;
      ta.value = notesCache[key] || '';
      ta.placeholder = 'Add a note… (Ctrl+Enter saves, Esc cancels)';

      const save = document.createElement('button');
      save.className = 'cn-save';
      save.textContent = 'Save';

      const cancel = document.createElement('button');
      cancel.className = 'cn-cancel';
      cancel.textContent = 'Cancel';

      editor.appendChild(ta);
      editor.appendChild(save);
      editor.appendChild(cancel);
      wrap.appendChild(editor);

      function resize() {
        ta.style.height = 'auto';
        ta.style.height = Math.min(ta.scrollHeight, 100) + 'px';
      }
      ta.addEventListener('input', resize);
      setTimeout(() => {
        resize();
        ta.focus();
        ta.setSelectionRange(ta.value.length, ta.value.length);
      }, 10);

      save.addEventListener('click', async () => {
        const val = ta.value.trim();
        await saveNote(key, val);
        closeEditor(val);
      });
      cancel.addEventListener('click', () => closeEditor(notesCache[key] || ''));
      ta.addEventListener('keydown', e => {
        if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) save.click();
        if (e.key === 'Escape') cancel.click();
      });
    }

    function closeEditor(finalNote) {
      const ed = wrap.querySelector('.cn-editor');
      if (ed) ed.remove();
      display.style.display = '';
      pencil.style.display = '';
      if (finalNote) {
        display.textContent = finalNote;
        display.classList.add('has-note');
        pencil.classList.add('active');
      } else {
        display.textContent = 'Add a note…';
        display.classList.remove('has-note');
        pencil.classList.remove('active');
      }
    }

    pencil.addEventListener('click', openEditor);
    display.addEventListener('click', openEditor);

    wrap.appendChild(pencil);
    wrap.appendChild(display);
    td.appendChild(wrap);
    tr.appendChild(td);
    return tr;
  }

  // ── Inject note rows ───────────────────────────────────────────────────────
  function injectAll() {
    document.querySelectorAll('tr.sortable').forEach(tr => {
      // Skip our own rows and skip folder-element rows
      if (tr.classList.contains('cn-row')) return;
      if (tr.classList.contains('folder-element')) return;

      // Must be either a folder header or individual container row
      const isFH = isFolderHeader(tr);
      const isCR = isContainerRow(tr);
      if (!isFH && !isCR) return;

      // Don't add twice
      const next = tr.nextElementSibling;
      if (next && next.classList.contains('cn-row')) return;

      const name = getNameFromRow(tr);
      if (!name) return;

      tr.parentNode.insertBefore(buildNoteRow(name), tr.nextSibling);
    });
  }

  // ── Watch for DOM changes (folder expand/collapse) ─────────────────────────
  function watch() {
    let timer = null;
    const obs = new MutationObserver(muts => {
      const relevant = muts.some(m =>
        [...m.addedNodes].some(n =>
          n.nodeType === 1 &&
          !n.classList?.contains('cn-row') &&
          (n.tagName === 'TR' || n.tagName === 'TBODY' || n.querySelector?.('tr.sortable'))
        )
      );
      if (relevant) {
        clearTimeout(timer);
        timer = setTimeout(injectAll, 250);
      }
    });
    obs.observe(document.body, { childList: true, subtree: true });
  }

  // ── Entry point ────────────────────────────────────────────────────────────
  async function init() {
    if (window.location.pathname !== '/Docker') return;
    injectStyles();
    await loadNotes();
    injectAll();
    watch();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();