// Execute the production export wrapper with in-memory SDK fixtures. No browser,
// external account, network, real ads or user files.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const cfg = fs.readFileSync(path.join(__dirname,'../export_presets.cfg'),'utf8').replace(/\r/g,'');
const html = cfg.match(/html\/head_include="([\s\S]*?)"\nhtml\/canvas_resize_policy/)[1];
let checks = 0;
function check(value,message) { checks++; assert.ok(value,message); }
async function fixture(available=true) {
  const calls = [], events = {}, ads = {};
  const player = {getUniqueID:()=> 'fixture',isAuthorized:()=>true,getData:async()=>({best:123}),setData:async(data)=>calls.push(['save',data])};
  const sdk = {environment:{i18n:{lang:'tr'},app:{id:123},payload:'c1-bright-42-18-11-100'},
    on:(key,callback)=>{events[key]=callback;},getPlayer:async()=>player,
    features:{LoadingAPI:{ready:()=>calls.push(['ready'])},GameplayAPI:{start:()=>calls.push(['start']),stop:()=>calls.push(['stop'])}},
    auth:{openAuthDialog:async()=>{}},
    adv:{showRewardedVideo:({callbacks})=>{ads.reward=callbacks;},showFullscreenAdv:({callbacks})=>{ads.fullscreen=callbacks;}},
    leaderboards:{setScore:(name,value)=>calls.push(['score',name,value]),getEntries:async()=>({userRank:1,entries:[{rank:1,score:123,player:{publicName:'Tester',uniqueID:'fixture'}}]})}};
  const window = {};
  const document = {hidden:false,addEventListener:(name,callback)=>{events[name]=callback;}};
  const navigator = {language:'ru',clipboard:{writeText:async(text)=>calls.push(['clipboard',text])}};
  const context = {window,document,navigator,URLSearchParams,location:{origin:'http://127.0.0.1',pathname:'/index.html',search:''},console};
  if(available) context.YaGames={init:async()=>sdk};
  vm.createContext(context);
  for(const script of html.matchAll(/<script>([\s\S]*?)<\/script>/g)) vm.runInContext(script[1],context);
  const ready = await new Promise(resolve=>window.YG.whenReady(resolve));
  return {yg:window.YG,ready,calls,events,ads,document,navigator,sdk};
}
async function run() {
  const f = await fixture();
  check(f.ready && f.yg.lang()==='tr','SDK readiness and language');
  check(f.yg.payload()==='c1-bright-42-18-11-100','Challenge payload');
  f.sdk.environment.payload='';
  let pause=0,resume=0;
  f.yg.onPause(()=>pause++); f.yg.onResume(()=>resume++);
  f.events.game_api_pause(); f.events.game_api_resume();
  f.document.hidden=true; f.events.visibilitychange(); f.document.hidden=false; f.events.visibilitychange();
  check(pause===2 && resume===2,'visibility and SDK pause/resume');
  for(const outcome of ['success','error','cancel']) {
    const result=[];
    f.yg.showRewarded(value=>result.push(value));
    f.ads.reward.onOpen();
    if(outcome==='success') f.ads.reward.onRewarded();
    if(outcome==='error') f.ads.reward.onError(); else f.ads.reward.onClose();
    check(result.length===1 && result[0]===(outcome==='success'),'reward result '+outcome);
    check(pause===resume,'reward closes platform pause '+outcome);
  }
  for(const outcome of ['shown','error','offline']) {
    const result=[];
    f.yg.showFullscreen(value=>result.push(value));
    if(outcome==='offline') f.ads.fullscreen.onOffline();
    else {f.ads.fullscreen.onOpen(); if(outcome==='error') f.ads.fullscreen.onError(); else f.ads.fullscreen.onClose(true);}
    check(result.length===1 && result[0]===(outcome==='shown'),'fullscreen result '+outcome);
    check(pause===resume,'fullscreen platform pause '+outcome);
  }
  check(JSON.parse(await new Promise(resolve=>f.yg.loadData(resolve))).best===123,'mock cloud read');
  f.yg.saveData('{"best":456}');
  check(f.calls.some(x=>x[0]==='save' && x[1].best===456),'mock cloud write');
  f.yg.setScore('bright',789);
  check(f.calls.some(x=>x[0]==='score' && x[1]==='bright' && x[2]===789),'mock score submission');
  const lb=JSON.parse(await new Promise(resolve=>f.yg.getEntries('bright',resolve)));
  check(lb.entries[0].me && lb.userRank===1,'mock leaderboard identity');
  check(await new Promise(resolve=>f.yg.openAuth(resolve)),'mock auth');
  check(await new Promise(resolve=>f.yg.share('c1-bright-42-18-11-100','Test',resolve))==='copied','clipboard fallback');
  check(f.calls.at(-1)[1].includes('?payload=c1-bright-42-18-11-100'),'Share encodes challenge link');
  f.navigator.share=async()=>{};
  check(await new Promise(resolve=>f.yg.share('payload','Test',resolve))==='shared','native browser share');
  f.navigator.share=async()=>{throw {name:'AbortError'};};
  check(await new Promise(resolve=>f.yg.share('payload','Test',resolve))==='cancel','Share cancellation');
  f.navigator.share=async()=>{throw Error('fixture');};
  check(await new Promise(resolve=>f.yg.share('payload','Test',resolve))==='copied','Share error clipboard fallback');
  f.navigator.clipboard.writeText=async()=>{throw Error('fixture');};
  check(await new Promise(resolve=>f.yg.share('payload','Test',resolve))==='fail','clipboard refusal');
  const missing=await fixture(false);
  check(!missing.ready,'missing SDK degrades safely');
  check(await new Promise(resolve=>missing.yg.showRewarded(resolve))===false,'missing SDK grants no reward');
  console.log('WEB_WRAPPER_DONE',JSON.stringify({checks,failed:0}));
}
run().catch(error=>{console.error(error);process.exitCode=1;});
