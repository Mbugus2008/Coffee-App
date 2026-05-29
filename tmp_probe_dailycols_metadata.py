import urllib.request, base64, time, re
u = 'http://test.trimline.co.ke:4548/BC240/ODataV4/%24metadata'
token = base64.b64encode(b'Philip:Password@2030').decode()
for i in range(6):
    try:
        req = urllib.request.Request(u)
        req.add_header('Authorization', 'Basic ' + token)
        req.add_header('Accept', 'application/xml')
        data = urllib.request.urlopen(req, timeout=30).read().decode('utf-8', 'ignore')
        print('ok', i + 1, len(data))
        m = re.search(r'<EntityType Name="DailyCollections">(.*?)</EntityType>', data, re.S)
        if not m:
            print('DailyCollections entity not found')
            break
        body = m.group(1)
        props = re.findall(r'<Property Name="([^"]+)"[^>]*Type="([^"]+)"[^>]*/?>', body)
        print('DailyCollections props:')
        for n, t in props:
            print(n, t)
        break
    except Exception as e:
        print('try', i + 1, 'failed', e)
        time.sleep(2)
