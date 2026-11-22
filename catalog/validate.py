"""Usage: python3 validate.py lessons/<slug>.json  — checks one lesson file."""
import json,sys,re
INTER={'tour','find','lines','explore'}
def check(path):
    d=json.load(open(path)); err=[]
    for k in ('teaser','focus','lesson','quiz','facts','review_notes'):
        if k not in d: err.append(f'missing key {k}')
    L=d.get('lesson',[])
    if not 11<=len(L)<=24: err.append(f'lesson has {len(L)} blocks (want 11-24)')
    prev=False
    def unit(v,what):
        if not (isinstance(v,(int,float)) and 0<=v<=1): err.append(f'{what} not in 0..1: {v}')
    for i,b in enumerate(L):
        t=b.get('type')
        if t not in {'text','key','fact','tour','find','lines','explore'}: err.append(f'block {i}: bad type {t}')
        if t in ('text','key','fact') and not b.get('text'): err.append(f'block {i}: empty text')
        if t in INTER:
            if prev: err.append(f'block {i}: two interactive blocks in a row')
            if i==0: err.append('lesson must not start with an interactive block')
        prev=t in INTER
        if t in ('tour','find','explore'):
            sp=b.get('spots') or []
            if t=='find' and len(sp)!=1: err.append(f'block {i}: find needs exactly 1 spot')
            if t=='tour' and not 2<=len(sp)<=4: err.append(f'block {i}: tour needs 2-4 spots')
            if t=='explore' and not 4<=len(sp)<=8: err.append(f'block {i}: explore needs 4-8 spots')
            if t in('tour','find') and not b.get('text'): err.append(f'block {i}: needs intro/question text')
            for s in sp:
                unit(s.get('x'),f'block {i} x'); unit(s.get('y'),f'block {i} y')
                if not 1.3<=s.get('zoom',0)<=5: err.append(f'block {i}: zoom out of range')
                if not 0.03<=s.get('r',0)<=0.3: err.append(f'block {i}: r out of range')
                if not s.get('title') or not s.get('text'): err.append(f'block {i}: spot needs title and text')
                if len(s.get('text',''))>230: err.append(f'block {i}: spot text too long ({len(s["text"])} > 230 chars)')
                if s.get('shape') not in (None,'circle','rect','arrow'): err.append(f'block {i}: bad shape')
        if t=='lines':
            ls=b.get('lines') or []
            if not 2<=len(ls)<=4: err.append(f'block {i}: lines needs 2-4 lines')
            for l in ls:
                if len(l.get('points',[]))<2: err.append(f'block {i}: line needs >=2 points')
                for p in l.get('points',[]):
                    unit(p[0],'line x'); unit(p[1],'line y')
                if not l.get('label') or not l.get('text'): err.append(f'block {i}: line needs label and text')
                if len(l.get('text',''))>230: err.append(f'block {i}: line text too long')
    n_inter=sum(1 for b in L if b.get('type') in INTER)
    if n_inter<1: err.append('needs at least one interactive block')
    if not any(b.get('type')=='fact' for b in L): err.append('needs at least one fact block')
    Q=d.get('quiz',[])
    if not 4<=len(Q)<=6: err.append(f'quiz has {len(Q)} questions (want 4-6)')
    for q in Q:
        if len(q.get('options',[]))!=3 or not 0<=q.get('answer',-1)<3 or not q.get('explanation'): err.append('bad quiz question: '+q.get('question','?'))
    F=d.get('facts',[])
    if len(F)!=3 or not any(f.get('isTrue') for f in F) or all(f.get('isTrue') for f in F): err.append('facts: need exactly 3, mixing true and false')
    f=d.get('focus',[])
    if len(f)!=2: err.append('focus must be [x,y]')
    txt=json.dumps(d,ensure_ascii=False)
    if '—' in txt: err.append('remove em dashes')
    return err
if __name__=='__main__':
    bad=0
    for p in sys.argv[1:]:
        e=check(p); print(p,'OK' if not e else e); bad+=bool(e)
    sys.exit(1 if bad else 0)
