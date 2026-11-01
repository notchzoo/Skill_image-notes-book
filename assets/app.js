/* 图片笔记页交互：悬浮目录 / 单节视图 / 搜索 / 双列 / 灯箱
   占位符 {{WIDE}} 与 {{STORAGE_KEY}} 由 build-page.ps1 注入。 */
const $=(sel,root=document)=>root.querySelector(sel);
const sections=[...document.querySelectorAll('#chapters section')];
const links=[...document.querySelectorAll('nav a')];
const pics=[...document.querySelectorAll('.picture')];
const bodyEl=document.body;
const sidebar=$('#chapter-sidebar');
const toggle=$('#sidebar-toggle');
const tcur=$('#toc-current');
const scrim=$('#toc-scrim');
const search=$('#search');
const result=$('#result');
const noResults=$('#no-results');
const dialog=$('dialog');
const large=$('#large');
const viewbody=$('.viewbody');
const WIDE={{WIDE}};
const STORE='{{STORAGE_KEY}}';
let current=sections[0]||null;
let picIndex=0;
let booting=true;

const tocOpen=()=>bodyEl.dataset.toc==='open';
function setToc(open,persist){
  bodyEl.dataset.toc=open?'open':'closed';
  toggle.setAttribute('aria-expanded',String(open));
  if(persist){try{localStorage.setItem(STORE,open?'open':'closed')}catch(e){}}
}
function labelOf(sec){
  const i=sections.indexOf(sec)+1;
  const name=sec.dataset.name;
  return i+'/'+sections.length+' · '+(name.length>20?name.slice(0,20)+'…':name);
}
function openSection(id,scroll){
  const target=sections.find(s=>s.id===id);
  if(!target)return;
  current=target;
  sections.forEach(s=>s.hidden=s!==target);
  links.forEach(a=>{const on=a.hash==='#'+id;a.classList.toggle('active',on);if(on)a.setAttribute('aria-current','page');else a.removeAttribute('aria-current')});
  tcur.textContent=labelOf(target);
  if(scroll)window.scrollTo({top:0,behavior:'instant'});
  if(!booting&&window.innerWidth<WIDE&&tocOpen())setToc(false,false);
}

toggle.addEventListener('click',()=>setToc(!tocOpen(),true));
scrim.addEventListener('click',()=>setToc(false,true));
document.addEventListener('click',e=>{
  if(!tocOpen()||dialog.open)return;
  if(sidebar.contains(e.target)||toggle.contains(e.target)||e.target.closest('nav a'))return;
  setToc(false,true);
});

function show(i){
  if(!pics.length)return;
  picIndex=(i+pics.length)%pics.length;
  const img=pics[picIndex].querySelector('img');
  large.src=img.src;
  large.alt=img.alt;
  $('#view-title').textContent=(picIndex+1)+' / '+pics.length+' · '+img.alt;
  viewbody.classList.remove('zoom');
  viewbody.scrollTop=0;
  viewbody.scrollLeft=0;
  $('#zoom').textContent='原始尺寸';
}
pics.forEach((b,i)=>b.addEventListener('click',()=>{show(i);dialog.showModal();document.body.style.overflow='hidden'}));
$('#prev').addEventListener('click',()=>show(picIndex-1));
$('#next').addEventListener('click',()=>show(picIndex+1));
$('#close').addEventListener('click',()=>dialog.close());
dialog.addEventListener('close',()=>{document.body.style.overflow=''});
function zoom(){const z=viewbody.classList.toggle('zoom');$('#zoom').textContent=z?'适应宽度':'原始尺寸'}
$('#zoom').addEventListener('click',zoom);
large.addEventListener('click',zoom);
dialog.addEventListener('click',e=>{if(e.target===dialog)dialog.close()});

document.addEventListener('keydown',e=>{
  if(dialog.open){
    if(e.key==='ArrowLeft'){e.preventDefault();show(picIndex-1)}
    else if(e.key==='ArrowRight'){e.preventDefault();show(picIndex+1)}
    return;
  }
  if(e.key==='Escape'&&tocOpen())setToc(false,true);
  if(e.key==='/'&&document.activeElement!==search){e.preventDefault();setToc(true,true);search.focus()}
});

$('#layout').addEventListener('click',e=>{
  const c=$('#chapters').classList.toggle('compact');
  e.currentTarget.textContent=c?'切换为单列阅读':'切换为双列浏览';
  e.currentTarget.setAttribute('aria-pressed',String(c));
});

search.addEventListener('input',()=>{
  const q=search.value.trim().toLowerCase();
  if(!q){
    links.forEach(a=>a.hidden=false);
    sections.forEach(s=>s.hidden=s!==current);
    noResults.hidden=true;
    result.textContent='按章节编号与图片文件名排序';
    return;
  }
  let n=0;
  let first=null;
  sections.forEach((s,i)=>{
    const ok=(s.dataset.name+' '+s.textContent).toLowerCase().includes(q);
    links[i].hidden=!ok;
    if(ok){n++;if(!first)first=s}
  });
  noResults.hidden=n!==0;
  result.textContent='找到 '+n+' 个章节';
  if(first)openSection(first.id,false);
  else sections.forEach(s=>s.hidden=true);
});

links.forEach(a=>a.addEventListener('click',e=>{e.preventDefault();history.pushState(null,'',a.hash);openSection(a.hash.slice(1),true)}));
function restoreSection(){
  const id=location.hash.slice(1);
  openSection(sections.some(s=>s.id===id)?id:sections[0].id,false);
}
window.addEventListener('popstate',restoreSection);

try{
  const stored=localStorage.getItem(STORE);
  setToc(stored?stored==='open':window.innerWidth>=WIDE,false);
}catch(e){setToc(window.innerWidth>=WIDE,false)}
restoreSection();
booting=false;
