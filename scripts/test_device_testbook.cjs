// Run with Playwright installed; REINA_CHROMIUM_EXECUTABLE may select an existing Chromium.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {pathToFileURL}=require('node:url');

(async()=>{
  const root=path.resolve(__dirname,'..');
  const version=/config\/version="([^"]+)"/.exec(fs.readFileSync(path.join(root,'client/project.godot'),'utf8'))[1];
  const url=pathToFileURL(path.join(root,'docs/DEVICE_TEST_RTS_008.html')).href;
  const launch={args:['--no-sandbox']};
  if(process.env.REINA_CHROMIUM_EXECUTABLE)launch.executablePath=process.env.REINA_CHROMIUM_EXECUTABLE;
  const browser=await chromium.launch(launch);
  const context=await browser.newContext({viewport:{width:390,height:844},hasTouch:true,acceptDownloads:true});
  await context.addInitScript(()=>Object.defineProperty(navigator,'clipboard',{value:{writeText:async text=>window.__copied=text}}));
  const page=await context.newPage();const errors=[];
  page.on('pageerror',e=>errors.push(e.message));await page.goto(url);
  const result=id=>page.locator('.case[data-id="'+id+'"] select');
  assert.equal(await page.locator('#tested-version').inputValue(),version);
  assert.equal(await page.locator('.case:visible').count(),36);
  const install=await page.locator('.note').first().textContent();
  assert(install.includes('REINA_RTS-'+version+'-debug.apk')&&install.includes('проверь версию '+version));
  await page.locator('#device').fill('QA phone');await page.locator('#android').fill('QA OS');
  await page.locator('#conditions').fill('Current run');await page.locator('#notes').fill('Current version notes');
  await result('build-preview').selectOption('pass');await result('build-operation-end').selectOption('skip');
  await page.locator('#export').click();const report=await page.locator('#report-text').inputValue();
  assert(report.includes('DEVICE TEST '+version)&&report.includes('2 / 36')&&report.includes('[ОК] 31.')&&report.includes('[Пропущено] 36.'));
  await page.locator('#copy-report').click();assert.equal(await page.evaluate(()=>window.__copied),report);
  const event=page.waitForEvent('download');await page.locator('#download-report').click();const download=await event;
  assert.equal(download.suggestedFilename(),'REINA_RTS-'+version+'-device-report.txt');
  assert.equal(fs.readFileSync(await download.path(),'utf8').replace(/^\uFEFF/,''),report);
  await page.locator('#tested-version').selectOption('0.0.14');
  assert((await page.locator('#counts').textContent()).includes('0 / 36'));
  assert.equal(await page.locator('#notes').inputValue(),'');assert.equal(await page.locator('#conditions').inputValue(),'');
  assert.equal(await page.locator('#device').inputValue(),'QA phone');
  await result('build-preview').selectOption('fail');await page.locator('#notes').fill('014 only');
  await page.locator('#tested-version').selectOption(version);
  assert.equal(await result('build-preview').inputValue(),'pass');assert.equal(await result('build-operation-end').inputValue(),'skip');
  assert.equal(await page.locator('#notes').inputValue(),'Current version notes');
  await page.reload();await page.waitForFunction(v=>document.getElementById('storage-state').textContent.startsWith('Восстановлены результаты '+v),version);
  assert.equal(await result('build-preview').inputValue(),'pass');
  await page.locator('#tested-version').selectOption('0.0.14');
  assert.equal(await result('build-preview').inputValue(),'fail');assert.equal(await page.locator('#notes').inputValue(),'014 only');
  page.once('dialog',d=>d.accept());await page.locator('#reset').click();
  assert.equal(await page.locator('#tested-version').inputValue(),'0.0.14');assert((await page.locator('#counts').textContent()).includes('0 / 36'));
  await page.locator('#tested-version').selectOption(version);assert.equal(await result('build-preview').inputValue(),'pass');
  for(const [old,count] of [['0.0.8',18],['0.0.9',18],['0.0.10',24],['0.0.11',24],['0.0.12',28],['0.0.13',30],['0.0.14',36]]){
    await page.evaluate(v=>{localStorage.clear();localStorage.setItem('reina-rts-device-test-008',JSON.stringify({version:v,fields:{device:'Legacy phone',notes:'Original '+v},results:{'large-map':'pass','build-preview':'pass'}}));},old);
    await page.reload();await page.waitForFunction(v=>document.getElementById('storage-state').textContent.startsWith('Восстановлены результаты '+v),old);
    assert.equal(await page.locator('#tested-version').inputValue(),old);assert.equal(await page.locator('.case:visible').count(),count);
    await page.locator('#export').click();const text=await page.locator('#report-text').inputValue();
    assert(text.includes('DEVICE TEST '+old)&&text.includes('Original '+old));
    assert.equal(text.includes('19. Большая карта'),count>=24);assert.equal(text.includes('29. Ответ без приказа'),count>=30);
    assert.equal(text.includes('31. Каталог и предпросмотр'),count===36);
    await page.locator('#tested-version').selectOption(version);
    assert((await page.locator('#counts').textContent()).includes('0 / 36'));assert.equal(await page.locator('#notes').inputValue(),'');
    await page.locator('#tested-version').selectOption(old);assert.equal(await page.locator('#notes').inputValue(),'Original '+old);
  }
  for(const width of [390,844,1280]){await page.setViewportSize({width,height:844});assert(await page.evaluate(()=>document.documentElement.scrollWidth-innerWidth<=1));}
  const blocked=await browser.newContext({viewport:{width:390,height:844}});
  await blocked.addInitScript(()=>{
    Object.defineProperty(window,'localStorage',{get(){throw Error('blocked')}});
    Object.defineProperty(navigator,'clipboard',{value:{writeText:async()=>{throw Error('blocked')}}});
    document.execCommand=()=>false;URL.createObjectURL=()=>{throw Error('blocked')};
  });
  const safe=await blocked.newPage();safe.on('pageerror',e=>errors.push(e.message));await safe.goto(url);
  await safe.locator('.case[data-id="build-preview"] select').selectOption('pass');await safe.locator('#notes').fill('Memory only');
  await safe.locator('#tested-version').selectOption('0.0.14');assert.equal(await safe.locator('#notes').inputValue(),'');
  await safe.locator('#tested-version').selectOption(version);assert.equal(await safe.locator('#notes').inputValue(),'Memory only');
  await safe.locator('#export').click();const text=await safe.locator('#report-text').inputValue();await safe.locator('#copy-report').click();
  assert((await safe.locator('#report-status').textContent()).includes('Автокопирование недоступно'));
  assert.equal(await safe.locator('#report-text').evaluate(e=>e.selectionEnd-e.selectionStart),text.length);
  await safe.locator('#download-report').click();assert((await safe.locator('#report-status').textContent()).includes('Скачивание здесь недоступно'));
  assert.equal(await safe.locator('#report-text').inputValue(),text);
  assert.deepEqual(errors,[]);await browser.close();
  console.log('TESTBOOK_AUDIT_PASS current='+version+' cases=36 history=isolated migration=7 reset=local copy=ok txt=ok fallback=ok widths=390,844,1280');
})().catch(e=>{console.error(e);process.exit(1)});
