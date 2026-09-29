import datetime as dt
import re
from pathlib import Path
from urllib.parse import urlsplit
from zoneinfo import ZoneInfo
from .storage import Store,read_file
from .shelf import local
from .process import launch
UTC=dt.timezone.utc
def local_zone():
    try:
        with open("/etc/localtime","rb") as f:return ZoneInfo.from_file(f)
    except (OSError,ValueError):return dt.datetime.now().astimezone().tzinfo

def date(value,params):
    if len(value)==8:return dt.datetime.strptime(value,'%Y%m%d').replace(tzinfo=local_zone())
    zone=UTC if value.endswith('Z') else ZoneInfo(params['TZID']) if params.get('TZID') else local_zone()
    return dt.datetime.strptime(value.rstrip('Z'),'%Y%m%dT%H%M%S').replace(tzinfo=zone)

def unescape(v):return v.replace('\\n','\n').replace('\\N','\n').replace('\\,',',').replace('\\;', ';').replace('\\\\','\\')

def web_url(value):
    u=urlsplit(value)
    if u.scheme not in ('https','http') or not u.hostname or u.username or u.password or len(value)>2048 or any(ord(x)<32 for x in value):raise ValueError('Meeting links must be ordinary HTTP(S) URLs')
    return value

def parse(data,now):
    text=data.decode('utf-8-sig');text=re.sub(r'\r?\n[ \t]','',text)
    if 'BEGIN:VCALENDAR' not in text or 'END:VCALENDAR' not in text:raise ValueError('Not an iCalendar document')
    records=[];current=None
    for line in text.splitlines():
        if line=='BEGIN:VEVENT':current={}
        elif line=='END:VEVENT':
            if current is not None:records.append(current)
            current=None
        elif current is not None and ':' in line:
            head,val=line.split(':',1);parts=head.split(';');params=dict(x.split('=',1) for x in parts[1:] if '=' in x)
            current.setdefault(parts[0].upper(),[]).append((val,params))
        if len(records)>2000:raise ValueError('Calendar exceeds 2000 events')
    events=[];unsupported=0;horizon=now+dt.timedelta(days=30)
    overrides={}
    for r in records:
        if 'RECURRENCE-ID' in r and 'UID' in r:
            try:overrides.setdefault(r['UID'][0][0],set()).add(date(*r['RECURRENCE-ID'][0]))
            except (ValueError,KeyError):pass
    for r in records:
        try:
            one=lambda key,default='':r.get(key,[(default,{})])[0][0]
            if one('STATUS')=='CANCELLED':continue
            start=date(*r['DTSTART'][0]);end=date(*r['DTEND'][0]) if 'DTEND' in r else start+(dt.timedelta(days=1) if len(r['DTSTART'][0][0])==8 else dt.timedelta(hours=1))
            if end<=start:end=start+dt.timedelta(minutes=30)
            starts=[start]
            if 'RRULE' in r and 'RECURRENCE-ID' not in r:
                rule=dict(x.split('=',1) for x in one('RRULE').split(';') if '=' in x)
                if rule.get('FREQ') not in ('DAILY','WEEKLY') or set(rule)-{'FREQ','INTERVAL','COUNT','UNTIL','BYDAY','WKST'}:
                    unsupported+=1;continue
                interval=int(rule.get('INTERVAL',1));count=int(rule.get('COUNT',10000))
                if interval<1 or count<1:raise ValueError('Invalid recurrence')
                until=date(rule['UNTIL'],{}) if 'UNTIL' in rule else horizon
                weekdays=['MO','TU','WE','TH','FR','SA','SU']
                days=rule.get('BYDAY',weekdays[start.weekday()]).split(',')
                if rule.get('WKST','MO') not in weekdays:unsupported+=1;continue
                weekstart=weekdays.index(rule.get('WKST','MO'))
                if any(x not in weekdays for x in days):unsupported+=1;continue
                starts=[];occurrences=0;day=start
                # Bounded expansion; calendars with very old, complex rules are reported partial.
                for i in range(20000):
                    if day>min(until,horizon) or occurrences>=count:break
                    weeks=((day.date()-dt.timedelta(days=(day.weekday()-weekstart)%7))-(start.date()-dt.timedelta(days=(start.weekday()-weekstart)%7))).days//7
                    match=(i%interval==0 and ('BYDAY' not in rule or weekdays[day.weekday()] in days)) if rule['FREQ']=='DAILY' else weeks%interval==0 and weekdays[day.weekday()] in days
                    if match:
                        occurrences+=1
                        if day+(end-start)>now:starts.append(day)
                    day+=dt.timedelta(days=1)
                else:unsupported+=1
            excluded=set() if 'RECURRENCE-ID' in r else overrides.get(one('UID'),set()).copy()
            for val,params in r.get('EXDATE',[]):
                for v in val.split(','):excluded.add(date(v,params))
            link=one('URL')
            if not link:
                match=re.search(r'https?://[^\s<>"\\]+',unescape(one('DESCRIPTION')+' '+one('LOCATION')))
                link=match.group(0) if match else ''
            try:link=web_url(link) if link else ''
            except ValueError:link=''
            for eventstart in starts:
                eventend=eventstart+(end-start)
                if eventstart in excluded or eventend<=now or eventstart>horizon:continue
                events.append({'title':unescape(one('SUMMARY','Untitled event'))[:160],'allDay':len(r['DTSTART'][0][0])==8,'start':int(eventstart.timestamp()*1000),'end':int(eventend.timestamp()*1000),'location':unescape(one('LOCATION'))[:200],'url':link})
        except (ValueError,KeyError,OverflowError):unsupported+=1
    return events,unsupported

def handle(op,p):
    store=Store('calendar')
    with store.lock():
        paths=store.load([])
        if not isinstance(paths,list) or len(paths)>8:raise ValueError('Calendar state is invalid')
        if op=='calendar-add':
            path=local(p.get('path',''))
            if path.suffix.lower()!='.ics':raise ValueError('Choose an .ics calendar file')
            parse(read_file(path,1048576),dt.datetime.now(UTC))
            paths=list(dict.fromkeys(paths+[str(path)]))
            if len(paths)>8:raise ValueError('At most eight calendar sources are supported')
            store.save(paths)
        elif op=='calendar-remove':paths=[x for x in paths if x!=p.get('path')];store.save(paths)
        events=[];warnings=[]
        for path in paths:
            try:
                found,skipped=parse(read_file(path,1048576),dt.datetime.now(UTC));events+=found
                if skipped:warnings.append(f'{Path(path).name}: {skipped} unsupported or invalid events')
            except (OSError,ValueError):warnings.append(f'{Path(path).name}: unavailable or invalid')
        events=sorted(events,key=lambda x:x['start'])[:60]
        if op=='calendar-join':
            url=web_url(p.get('url',''))
            if not any(x['url']==url for x in events):raise ValueError('Meeting link is no longer in the current agenda')
            launch(['xdg-open',url])
        return {'events':events,'sources':paths,'message':'; '.join(warnings)[:500] or ('No events in the next 30 days' if not events else '')}
