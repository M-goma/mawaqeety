import re,json,random
D=re.compile(r'[ً-ْٰـ]')
def plain_map(t):
    out=[];idx=[]
    for i,c in enumerate(t):
        if D.match(c): continue
        out.append(c); idx.append(i)
    return ''.join(out),idx
PROPHET=re.compile(r'(رسول الله|النبي|رسول اللهِ)')
RADI=re.compile(r'رض[يى] الله عن')
MARK=re.compile(r'(?:^|[\s،,:])(عن|سمعت|أن|أنه|أنها|حدثني|حدثتني|أخبرني|أخبرتني|قال|قالت)\s')
def matn_start(t):
    p,idx=plain_map(t)
    m=PROPHET.search(p)
    if not m: return -1
    end=m.start()
    r=None
    for x in RADI.finditer(p[:end]): r=x
    anchor = r.start() if r else end
    # companion name sits right before "رضي الله عنه": find the narrator marker before it
    cands=[x for x in MARK.finditer(p[:anchor]) if x.group(1) in ('عن','سمعت','أن','أنه','أنها','حدثني','حدثتني','أخبرني','أخبرتني')]
    # "عن النبي": step back to the companion who narrates from him
    while len(cands) > 1 and end - cands[-1].end() < 3:
        cands.pop()
    if not cands: return -1
    s=cands[-1].start(1)
    if s < 15: return -1  # nothing worth hiding
    return idx[s]
if __name__=='__main__':
    for e in ['ara-bukhari','ara-muslim']:
        d=json.load(open(f'/tmp/{e}.json'));hs=[h for h in d['hadiths'] if h['text'].strip()]
        n=sum(1 for h in hs if matn_start(h['text'])>=0); print(e,n,len(hs))
        random.seed(3)
        for h in random.sample(hs,6):
            s=matn_start(h['text']); print('---',h['hadithnumber'],'|', h['text'][s:s+160] if s>=0 else 'FULL')
