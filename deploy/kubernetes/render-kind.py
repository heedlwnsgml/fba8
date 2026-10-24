import sys,re,pathlib,yaml
source,lock,destination=map(pathlib.Path,sys.argv[1:])
images={}
for line in lock.read_text().splitlines():
 if not line.strip():continue
 key,value=line.split('=',1)
 if key in ('BACKEND_IMAGE','FRONTEND_IMAGE','DATABASE_IMAGE'):
  if not re.fullmatch(r'[\w./:-]+@sha256:[a-f0-9]{64}',value):raise ValueError('Expected immutable registry image')
  images[key]=value
text=source.read_text()
for key in ('BACKEND_IMAGE','FRONTEND_IMAGE','DATABASE_IMAGE'):text=text.replace(key+'_DIGEST',images[key])
docs=list(yaml.safe_load_all(text))
for doc in docs:
 if doc['kind']=='Service' and doc['metadata']['name'] in ('backend','frontend'):
  doc['spec']['type']='NodePort'
  doc['spec']['ports'][0]['nodePort']=30080 if doc['metadata']['name']=='backend' else 30081
 if doc['kind']=='StatefulSet':
  doc['spec']['template']['spec']['containers'][0]['args']=['--character-set-server=utf8mb4','--collation-server=utf8mb4_unicode_ci','--innodb-buffer-pool-size=256M','--max-connections=100']
destination.parent.mkdir(parents=True,exist_ok=True)
destination.write_text(yaml.safe_dump_all(docs,sort_keys=False))
