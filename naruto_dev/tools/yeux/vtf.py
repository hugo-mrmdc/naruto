import struct
from PIL import Image
def c565(c): return ((c>>11&31)*255//31, (c>>5&63)*255//63, (c&31)*255//31)
def dxt(data,w,h,kind):
    img=Image.new('RGBA',(w,h)); px=img.load(); bs=8 if kind=='DXT1' else 16; o=0
    for by in range(0,h,4):
        for bx in range(0,w,4):
            b=data[o:o+bs]; o+=bs
            if kind=='DXT5':
                a0,a1=b[0],b[1]; bits=int.from_bytes(b[2:8],'little')
                al=[a0,a1]+([((6-i)*a0+(i+1)*a1)//7 for i in range(6)] if a0>a1 else [((4-i)*a0+(i+1)*a1)//5 for i in range(4)]+[0,255])
                cb=b[8:]
            else: cb=b; al=None
            c0,c1,idx=struct.unpack('<HHI',cb[:8]); p0,p1=c565(c0),c565(c1)
            if c0>c1 or kind!='DXT1': cols=[p0,p1,tuple((2*a+b_)//3 for a,b_ in zip(p0,p1)),tuple((a+2*b_)//3 for a,b_ in zip(p0,p1))]
            else: cols=[p0,p1,tuple((a+b_)//2 for a,b_ in zip(p0,p1)),(0,0,0)]
            for i in range(16):
                x,y=bx+i%4,by+i//4
                a=al[(bits>>(3*i))&7] if al else 255
                px[x,y]=cols[(idx>>(2*i))&3]+(a,)
    return img
def lire(p):
    d=open(p,'rb').read(); w,h=struct.unpack_from('<HH',d,16); fmt=struct.unpack_from('<i',d,52)[0]
    kind={13:'DXT1',15:'DXT5'}[fmt]; n=w*h//(2 if kind=='DXT1' else 1)
    return dxt(d[-n:],w,h,kind)
