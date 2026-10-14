// Local exported WebAssembly regression. Fresh browser context, loopback-only network,
// engine Dummy args + actual Godot guard + muted browser process. Never publishes.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { chromium } = require('playwright');
const root = path.resolve(__dirname, '..');
const artifacts = path.resolve(process.argv[2] || '');
assert.match(path.relative(path.join(root, 'build', 'verification'), artifacts), /^[0-9a-f]{32}[\\/]exports$/);
const metadata = JSON.parse(fs.readFileSync(path.join(artifacts, 'verification.json'), 'utf8'));
const web = path.join(artifacts, 'web');
const mime = {'.html':'text/html', '.js':'application/javascript', '.wasm':'application/wasm', '.png':'image/png', '.pck':'application/octet-stream'};
let browser, browserServer, server, deadline;
const messages = [], errors = [], results = [];
function killOwnedBrowser() {
  if(!browserServer || browserServer.process().exitCode !== null) return;
  // Avoid Playwright's shell-built taskkill command: invoke the native binary
  // with the PID of the browser this harness created, including only its children.
  execFileSync(path.join(process.env.SystemRoot,'System32','taskkill.exe'),['/PID',String(browserServer.process().pid),'/T','/F'],{windowsHide:true,stdio:'ignore'});
}
async function run() {
  server = http.createServer((req, res) => {
    const name = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname);
    const filename = name === '/sdk.js' ? path.join(root, 'tools/mock/sdk.js') : path.resolve(web, '.' + (name === '/' ? '/index.html' : name));
    if (name !== '/sdk.js' && !filename.startsWith(web + path.sep)) { res.writeHead(403).end(); return; }
    if (!fs.existsSync(filename) || !fs.statSync(filename).isFile()) { res.writeHead(404).end(); return; }
    res.setHeader('Content-Type', mime[path.extname(filename)] || 'application/octet-stream');
    res.setHeader('Cache-Control','no-store');
    fs.createReadStream(filename).pipe(res);
  });
  await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;
  const executablePath = process.env.BIZARRE_TEST_CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
  browserServer = await chromium.launchServer({executablePath,headless:true,host:'127.0.0.1',args:['--mute-audio','--no-first-run']});
  browser = await chromium.connect(browserServer.wsEndpoint());
  deadline = setTimeout(()=>{
    console.error('Web verification timeout; terminating its owned browser.');
    try { killOwnedBrowser(); } finally { process.exit(1); }
  },300000);
  fs.writeFileSync(path.join(artifacts, 'browser-launch.json'), JSON.stringify({origin,executablePath,browserPid:browserServer.process().pid,args:['--mute-audio','--no-first-run'],engineArgs:['--audio-driver','Dummy'],profile:'fresh Playwright browser context'},null,2));
  const context = await browser.newContext({viewport:{width:1280,height:720}});
  // Exercise clipboard fallback without opening an OS share sheet.
  await context.addInitScript(()=>{
    let text = '';
    Object.defineProperty(navigator,'share',{value:undefined,configurable:true});
    Object.defineProperty(navigator,'clipboard',{value:{writeText:async value=>{text=value;},readText:async()=>text},configurable:true});
  });
  await context.route('**/*', async route => {
    // Fetch via Playwright's API transport, then serve the local HTTP response to
    // the browser. This avoids machine-installed browser HTTP script injection.
    if (new URL(route.request().url()).origin === origin) return route.fulfill({response:await route.fetch()});
    errors.push('External request blocked: ' + route.request().url());
    return route.abort();
  });
  const page = await context.newPage();
  page.on('console', message => { messages.push(message.text()); fs.appendFileSync(path.join(artifacts,'browser-live.log'),message.text()+'\n'); if (message.type() === 'error') errors.push(message.text()); });
  page.on('pageerror', error => errors.push(String(error)));
  await page.goto(origin + '/index.html?lang=en');
  await page.waitForFunction(() => window.__bizarreResult, null, {timeout:180000});
  const first = await page.evaluate(() => window.__bizarreResult);
  assert.equal(first.failed,0,JSON.stringify(first));
  assert.equal(first.audio_driver,'Dummy');
  assert.ok(messages.some(x=>x.includes('ISOLATED_AUDIO_DUMMY')));
  results.push(first);
  async function command(value) {
    await page.evaluate(value=> { delete window.__bizarreState; window.__bizarreCommand(value); },value);
    await page.waitForFunction(value=>window.__bizarreState?.command === value,value,{timeout:15000});
    return page.evaluate(()=>window.__bizarreState);
  }
  for (const mode of ['classic','bright','daily','tutorial']) {
    let state = await command(mode);
    assert.equal(state.mode,mode === 'daily' ? 'bright' : mode);
    if (mode === 'tutorial') {
      const canvas = await page.locator('canvas').boundingBox();
      await page.mouse.click(canvas.x + state.target[0] * canvas.width / state.viewport[0],canvas.y + state.target[1] * canvas.height / state.viewport[1]);
      state = await command('inspect');
      assert.ok(state.hits > 0,'real canvas mouse event advances interactive lesson');
    }
    for (const viewport of [{width:1280,height:720},{width:390,height:844},{width:620,height:600},{width:1280,height:720}]) {
      const dims = state.dims;
      await page.setViewportSize(viewport);
      state = await command('inspect');
      if(mode==='bright' || mode==='daily') assert.deepEqual(state.dims,dims,'Run/Daily field remains latched through real browser resize');
      assert.ok(state.board.every(n=>n>0),'real Web board dimensions');
      assert.ok(state.stats.every(n=>n>0),'real Web HUD dimensions');
      await page.screenshot({path:path.join(artifacts,`web-${mode}-${viewport.width}.png`)});
      results.push({mode,viewport,state});
    }
    await command('menu');
  }
  const afterTutorial = await command('bright');
  const direct = results.find(r=>r.mode==='bright' && r.viewport.width===1280).state;
  for(const key of ['dims','board','stats']) assert.deepEqual(afterTutorial[key],direct[key],'Web HUD route independence: '+key);
  await page.evaluate(()=>document.querySelector('canvas').addEventListener('pointerdown',()=>document.querySelector('canvas').requestFullscreen(),{once:true}));
  await page.mouse.click(3,3);
  await page.waitForFunction(()=>document.fullscreenElement);
  results.push({fullscreen:true,state:await command('inspect')});
  await page.evaluate(()=>document.exitFullscreen());
  await page.waitForFunction(()=>!document.fullscreenElement);
  await command('menu');
  const tutorial = await command('tutorial');
  const canvas = await page.locator('canvas').boundingBox();
  const cdp = await context.newCDPSession(page);
  await cdp.send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:2});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:canvas.x+tutorial.target[0]*canvas.width/tutorial.viewport[0],y:canvas.y+tutorial.target[1]*canvas.height/tutorial.viewport[1]}]});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  const touch = await command('inspect');
  assert.ok(touch.hits>0,'real browser touch advances interactive lesson');
  results.push({touch:true,state:touch});
  await cdp.send('Emulation.setTouchEmulationEnabled',{enabled:false});
  await command('menu');
  const payload = 'c1-bright-42-18-11-100';
  assert.equal(await page.evaluate(payload=>new Promise(resolve=>window.YG.share(payload,'Fixture Challenge',resolve)),payload),'copied');
  assert.ok((await page.evaluate(()=>navigator.clipboard.readText())).includes('?payload='+payload),'browser clipboard fixture contains local challenge link without changing OS clipboard');
  // Browser reload exercises IndexedDB user:// persistence, not a new in-memory Save.
  await page.setViewportSize({width:390,height:844});
  await page.goto(origin+'/index.html?lang=tr&reload=1&inset=32');
  await page.waitForFunction(()=>window.__bizarreResult,null,{timeout:90000});
  const reload = await page.evaluate(()=>window.__bizarreResult);
  assert.equal(reload.failed,0,JSON.stringify(reload));
  results.push(reload);
  assert.ok((await command('daily')).safe.includes('32'),'real Web debug safe area fixture is applied');
  assert.ok(!messages.some(x=>/SCRIPT ERROR:|ERROR:|\bFAIL\b/.test(x)),messages.filter(x=>/ERROR:|\bFAIL\b/.test(x)).join('\n'));
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(artifacts,'web-runtime.json'),JSON.stringify({passed:true,metadata,browser:browser.version(),platform:'Windows Chrome/WebGL; desktop context resized to portrait, CDP emulated touch; not physical Android',results,errors},null,2));
  console.log('WEB_RUNTIME_DONE',artifacts);
}
run().catch(error=>{ console.error(error); process.exitCode=1; }).finally(async()=>{
  fs.writeFileSync(path.join(artifacts,'browser-console.log'),messages.join('\n'));
  fs.writeFileSync(path.join(artifacts,'browser-errors.json'),JSON.stringify(errors,null,2));
  if(browserServer) {
    killOwnedBrowser();
    await new Promise(resolve=>browserServer.process().exitCode !== null ? resolve() : browserServer.process().once('exit',resolve));
  }
  // route.fetch owns HTTP keep-alive connections even after Chrome exits.
  // Close only this harness's loopback connections so cleanup cannot hang.
  if(server) { server.closeAllConnections(); await new Promise(resolve=>server.close(resolve)); }
  clearTimeout(deadline);
});
