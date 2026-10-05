var periods=['today','7d','mtd','30d'];
var labels={stripe:['Revenue','Net after fees','MRR estimate','ARR estimate','Paying subscribers','ARPU'],paddle:['Net revenue','MRR','ARR'],shopify:['Order value','Orders','Average order value']};
function tile(raw){raw=raw&&typeof raw==='object'?raw:{};return {accountId:typeof raw.accountId==='string'&&/^[a-f0-9]{24}$/.test(raw.accountId)?raw.accountId:'',metric:Object.keys(labels).some(p=>labels[p].indexOf(raw.metric)>=0)?raw.metric:'',period:periods.indexOf(raw.period)>=0?raw.period:'7d',currency:typeof raw.currency==='string'&&/^[A-Z]{3}$/.test(raw.currency)?raw.currency:'USD',timeZone:typeof raw.timeZone==='string'&&/^[A-Za-z0-9_+\-/]{1,80}$/.test(raw.timeZone)?raw.timeZone:'local',chart:raw.chart!==false};}
function tiles(raw){var result={};Object.keys(raw||{}).filter(k=>k==='business'||/^business:[a-z0-9-]{1,32}$/.test(k)).slice(0,8).forEach(k=>result[k]=tile(raw[k]));return result;}
function request(config,account){return {accountId:config.accountId,currency:config.currency,period:config.period,timeZone:config.timeZone,revision:account?account.revision:''};}
function key(config,account){return JSON.stringify(request(config,account));}
function metric(report,config,account){var wanted=config.metric||((labels[account?account.provider:'']||[])[0]);return report?(report.metrics||[]).find(m=>m.label===wanted)||null:null;}
if(typeof module!=='undefined')module.exports={periods,labels,tile,tiles,key,request,metric};
