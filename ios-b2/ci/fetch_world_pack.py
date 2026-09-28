#!/usr/bin/env python3
"""Materialize both pinned archives, streaming SHA validation before Xcode."""
import hashlib,json,pathlib,tempfile,urllib.request,urllib.parse,os
root=pathlib.Path(__file__).resolve().parents[1]
def digest_file(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  while data:=f.read(1024*1024):h.update(data)
 return h.hexdigest()
def fetch_pack(descriptor,filename):
 m=json.loads((root/'Resources'/descriptor).read_text());target=root/'Resources'/filename
 u=urllib.parse.urlsplit(m['url'])
 assert u.scheme=='https' and u.netloc=='like-art.com' and u.path.startswith('/v6/pack/') and not u.query and not u.fragment
 assert 0<m['bytes']<200*1024*1024 and len(m['sha256'])==64
 if target.exists() and target.stat().st_size==m['bytes'] and digest_file(target)==m['sha256']:
  print('Verified bundled pack already present:',m['version']);return
 fd,name=tempfile.mkstemp(prefix='world-pack-',dir=target.parent)
 try:
  digest=hashlib.sha256();total=0
  with os.fdopen(fd,'wb') as out,urllib.request.urlopen(m['url'],timeout=30) as response:
   while data:=response.read(1024*1024):
    total+=len(data);assert total<=m['bytes'];digest.update(data);out.write(data)
  assert total==m['bytes'] and digest.hexdigest()==m['sha256'],'Pack hash/size mismatch'
  os.replace(name,target);print('Verified bundled pack downloaded:',m['version'],total)
 finally:
  if os.path.exists(name):os.unlink(name)
fetch_pack('v6-pack.json','v6-base-assets.pak')
fetch_pack('v6-room-pack.json','v6-room-assets.pak')
