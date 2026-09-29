import datetime as dt
import functools
import re
from pathlib import Path
from urllib.parse import urlsplit
from zoneinfo import ZoneInfo
from .storage import Store,read_file
from .shelf import local
from .process import launch
UTC=dt.timezone.utc
WEEKDAYS=['MO','TU','WE','TH','FR','SA','SU']

@functools.lru_cache(maxsize=1)
def local_zone():
    try:
        with open("/etc/localtime","rb") as f:return ZoneInfo.from_file(f)
    except (OSError,ValueError):return dt.datetime.now().astimezone().tzinfo

def offset(value):
    sign=-1 if value.startswith('-') else 1;digits=value.lstrip('+-')
    if not re.fullmatch(r'\d{4}(\d{2})?',digits):raise ValueError('Invalid UTC offset')
    return dt.timedelta(hours=int(digits[:2]),minutes=int(digits[2:4]),seconds=int(digits[4:6] or 0))*sign

class RuleZone(dt.tzinfo):
    """Fixed or two-rule zone built from a VTIMEZONE block (Outlook/Exchange names are not IANA keys)."""
    def __init__(self,name,standard,daylight):
        self.name=name;self.standard=standard;self.daylight=daylight
    def transition(self,rule,year):
        # Windows-style transitions: DTSTART time of day, YEARLY BYMONTH plus BYDAY like 2SU or -1SU.
        month=int(rule['month']);nth=rule['nth'];weekday=rule['weekday']
        if nth>0:
            first=dt.date(year,month,1);day=first+dt.timedelta(days=(weekday-first.weekday())%7+7*(nth-1))
        else:
            last=(dt.date(year+(month==12),month%12+1,1)-dt.timedelta(days=1));day=last-dt.timedelta(days=(last.weekday()-weekday)%7+7*(-nth-1))
        return dt.datetime.combine(day,rule['time'])
    def in_daylight(self,value):
        if not self.daylight or 'month' not in self.daylight:return False
        naive=value.replace(tzinfo=None);on=self.transition(self.daylight,naive.year);off=self.transition(self.standard,naive.year)
        return on<=naive<off if on<off else not (off<=naive<on)
    def utcoffset(self,value):return self.daylight['offset'] if self.in_daylight(value) else self.standard['offset']
    def dst(self,value):return self.daylight['offset']-self.standard['offset'] if self.in_daylight(value) else dt.timedelta(0)
    def tzname(self,value):return self.name

def rule_block(props):
    block={'offset':offset(props['TZOFFSETTO'][0][0])}
    rule=dict(x.split('=',1) for x in props.get('RRULE',[('',{})])[0][0].split(';') if '=' in x)
    match=re.fullmatch(r'(-?[1-4])(MO|TU|WE|TH|FR|SA|SU)',rule.get('BYDAY',''))
    if rule.get('FREQ')=='YEARLY' and match and rule.get('BYMONTH','').isdigit():
        stamp=props.get('DTSTART',[('19700101T020000',{})])[0][0]
        block.update(month=rule['BYMONTH'],nth=int(match.group(1)),weekday=WEEKDAYS.index(match.group(2)),time=dt.datetime.strptime(stamp[-6:],'%H%M%S').time())
    return block

def zone(name,zones):
    if not name:return local_zone()
    try:return ZoneInfo(name)
    except (ValueError,KeyError,OSError):
        if name in zones:return zones[name]
        raise ValueError('Unknown time zone '+name[:60])

def date(value,params,zones=None):
    if len(value)==8:return dt.datetime.strptime(value,'%Y%m%d').replace(tzinfo=local_zone())
    tz=UTC if value.endswith('Z') else zone(params.get('TZID',''),zones or {})
    return dt.datetime.strptime(value.rstrip('Z'),'%Y%m%dT%H%M%S').replace(tzinfo=tz)

def duration(value):
    match=re.fullmatch(r'([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?',value)
    if not match:raise ValueError('Invalid duration')
    sign,w,d,h,m,s=match.groups()
    return dt.timedelta(weeks=int(w or 0),days=int(d or 0),hours=int(h or 0),minutes=int(m or 0),seconds=int(s or 0))*(-1 if sign=='-' else 1)

def unescape(v):return v.replace('\\n','\n').replace('\\N','\n').replace('\\,',',').replace('\\;', ';').replace('\\\\','\\')

def web_url(value):
    u=urlsplit(value)
    if u.scheme not in ('https','http') or not u.hostname or u.username or u.password or len(value)>2048 or any(ord(x)<32 for x in value):raise ValueError('Meeting links must be ordinary HTTP(S) URLs')
    return value

def components(text):
    """Yield (kind, properties) for VEVENT and VTIMEZONE blocks; nested components (VALARM) never leak into their parent."""
    stack=[]
    for line in text.splitlines():
        if line.startswith('BEGIN:'):
            stack.append((line[6:].upper(),{}))
            if stack[-1][0] in ('STANDARD','DAYLIGHT') and len(stack)>1:stack[-2][1].setdefault(stack[-1][0],[]).append(stack[-1][1])
        elif line.startswith('END:'):
            if stack and stack[-1][0]==line[4:].upper():
                kind,props=stack.pop()
                if kind in ('VEVENT','VTIMEZONE'):yield kind,props
        elif stack and ':' in line and stack[-1][0] in ('VEVENT','VTIMEZONE','STANDARD','DAYLIGHT'):
            head,val=line.split(':',1);parts=head.split(';');params=dict((k,v.strip('"')) for k,v in (x.split('=',1) for x in parts[1:] if '=' in x))
            stack[-1][1].setdefault(parts[0].upper(),[]).append((val,params))

def parse(data,now):
    text=data.decode('utf-8-sig');text=re.sub(r'\r?\n[ \t]','',text)
    if 'BEGIN:VCALENDAR' not in text or 'END:VCALENDAR' not in text:raise ValueError('Not an iCalendar document')
    records=[];zones={}
    for kind,props in components(text):
        if kind=='VTIMEZONE':
            try:
                name=props['TZID'][0][0];standard=rule_block((props.get('STANDARD') or props['DAYLIGHT'])[0])
                zones[name]=RuleZone(name,standard,rule_block(props['DAYLIGHT'][0]) if props.get('DAYLIGHT') else None)
            except (KeyError,ValueError,IndexError):pass
        else:
            records.append(props)
            if len(records)>2000:raise ValueError('Calendar exceeds 2000 events')
    events=[];unsupported=0;horizon=now+dt.timedelta(days=30)
    overrides={}
    for r in records:
        if 'RECURRENCE-ID' in r and 'UID' in r:
            try:overrides.setdefault(r['UID'][0][0],set()).add(date(*r['RECURRENCE-ID'][0],zones))
            except (ValueError,KeyError):pass
    for r in records:
        try:
            one=lambda key,default='':r.get(key,[(default,{})])[0][0]
            if one('STATUS')=='CANCELLED':continue
            allday=len(r['DTSTART'][0][0])==8
            start=date(*r['DTSTART'][0],zones)
            if 'DTEND' in r:end=date(*r['DTEND'][0],zones)
            elif 'DURATION' in r:end=start+duration(one('DURATION'))
            else:end=start+(dt.timedelta(days=1) if allday else dt.timedelta(hours=1))
            if end<=start:end=start+dt.timedelta(minutes=30)
            length=end-start
            starts=[start]
            if 'RRULE' in r and 'RECURRENCE-ID' not in r:
                rule=dict(x.split('=',1) for x in one('RRULE').split(';') if '=' in x)
                if rule.get('FREQ') not in ('DAILY','WEEKLY') or set(rule)-{'FREQ','INTERVAL','COUNT','UNTIL','BYDAY','WKST'}:
                    unsupported+=1;continue
                interval=int(rule.get('INTERVAL',1));count=int(rule.get('COUNT',10000))
                if interval<1 or count<1:raise ValueError('Invalid recurrence')
                until=date(rule['UNTIL'],{},zones) if 'UNTIL' in rule else horizon
                days=rule.get('BYDAY',WEEKDAYS[start.weekday()]).split(',')
                if rule.get('WKST','MO') not in WEEKDAYS:unsupported+=1;continue
                weekstart=WEEKDAYS.index(rule.get('WKST','MO'))
                if any(x not in WEEKDAYS for x in days):unsupported+=1;continue
                starts=[];occurrences=0;day=start;first=0
                # Without COUNT the past cannot matter: jump to the interval-aligned step nearest the window.
                if 'COUNT' not in rule:
                    behind=max(0,((now-length)-start).days)
                    first=behind//interval*interval if rule['FREQ']=='DAILY' else behind//(7*interval)*(7*interval)
                    day=start+dt.timedelta(days=first)
                for i in range(first,first+20000):
                    if day>min(until,horizon) or occurrences>=count:break
                    weeks=((day.date()-dt.timedelta(days=(day.weekday()-weekstart)%7))-(start.date()-dt.timedelta(days=(start.weekday()-weekstart)%7))).days//7
                    match=(i%interval==0 and ('BYDAY' not in rule or WEEKDAYS[day.weekday()] in days)) if rule['FREQ']=='DAILY' else weeks%interval==0 and WEEKDAYS[day.weekday()] in days
                    if match:
                        occurrences+=1
                        if day+length>now:starts.append(day)
                    day+=dt.timedelta(days=1)
                else:unsupported+=1
            excluded=set() if 'RECURRENCE-ID' in r else overrides.get(one('UID'),set()).copy()
            for val,params in r.get('EXDATE',[]):
                for v in val.split(','):excluded.add(date(v,params,zones))
            link=one('URL')
            if not link:
                match=re.search(r'https?://[^\s<>"\\]+',unescape(one('DESCRIPTION')+' '+one('LOCATION')))
                link=match.group(0).rstrip('.,;:)]}\'') if match else ''
            try:link=web_url(link) if link else ''
            except ValueError:link=''
            for eventstart in starts:
                eventend=eventstart+length
                if eventstart in excluded or eventend<=now or eventstart>horizon:continue
                events.append({'title':unescape(one('SUMMARY','Untitled event'))[:160],'allDay':allday,'start':int(eventstart.timestamp()*1000),'end':int(eventend.timestamp()*1000),'location':unescape(one('LOCATION'))[:200],'url':link})
        except (ValueError,KeyError,OverflowError):unsupported+=1
    return events,unsupported

def handle(op,p):
    store=Store('calendar')
    with store.lock():
        paths=store.load([])
        if not isinstance(paths,list) or len(paths)>8:raise ValueError('Calendar state is invalid')
        now=dt.datetime.now(UTC);parsed={}
        if op=='calendar-add':
            path=local(p.get('path',''))
            if path.suffix.lower()!='.ics':raise ValueError('Choose an .ics calendar file')
            parsed[str(path)]=parse(read_file(path,1048576),now)
            paths=list(dict.fromkeys(paths+[str(path)]))
            if len(paths)>8:raise ValueError('At most eight calendar sources are supported')
            store.save(paths)
        elif op=='calendar-remove':paths=[x for x in paths if x!=p.get('path')];store.save(paths)
        events=[];warnings=[]
        for path in paths:
            try:
                found,skipped=parsed.get(path) or parse(read_file(path,1048576),now);events+=found
                if skipped:warnings.append(f'{Path(path).name}: {skipped} unsupported or invalid events')
            except (OSError,ValueError):warnings.append(f'{Path(path).name}: unavailable or invalid')
        events=sorted(events,key=lambda x:x['start'])[:60]
        if op=='calendar-join':
            url=web_url(p.get('url',''))
            if not any(x['url']==url for x in events):raise ValueError('Meeting link is no longer in the current agenda')
            launch(['xdg-open',url])
        return {'events':events,'sources':paths,'message':'; '.join(warnings)[:500] or ('No events in the next 30 days' if not events else '')}
