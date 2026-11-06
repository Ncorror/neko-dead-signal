"""Geometry QA renderer for the authored GLB source meshes; not an in-game screenshot."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont


def render(models, output):
    output=Path(output)
    output.parent.mkdir(parents=True,exist_ok=True)
    cell_w,cell_h=320,265
    canvas=Image.new('RGB',(cell_w*5,cell_h*4+70),'#12232e')
    draw=ImageDraw.Draw(canvas)
    font_path='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    font=ImageFont.truetype(font_path,15)
    small=ImageFont.truetype(font_path,12)
    draw.text((22,18),'FRONTIER v1 / authored mesh kit',font=ImageFont.truetype(font_path,24),fill='#d8e7e8')
    draw.text((22,48),'Geometry review: individual assets, normalized view. Not a gameplay capture.',font=small,fill='#93b1bc')
    view=np.array([1.,1.35,1.2]);view/=np.linalg.norm(view)
    right=np.cross([0,1,0],view);right/=np.linalg.norm(right)
    up=np.cross(view,right)
    light=np.array([-.4,1,.8]);light/=np.linalg.norm(light)
    for number,(name,mesh) in enumerate(models.items()):
        w,h=cell_w-16,cell_h-50
        pix=np.zeros((h,w,3),dtype=np.float32);pix[:]=[.075,.135,.17]
        depth=np.full((h,w),-np.inf,dtype=np.float32)
        p=np.array(mesh.positions,dtype=np.float32)
        q=np.column_stack((p@right,-p@up,p@view))
        lo=q[:,:2].min(axis=0);hi=q[:,:2].max(axis=0)
        scale=min((w-35)/max(hi[0]-lo[0],.01),(h-28)/max(hi[1]-lo[1],.01))
        q[:,:2]=(q[:,:2]-(lo+hi)/2)*scale+np.array([w/2,h/2])
        norms=np.array(mesh.normals).reshape(-1,3,3)[:,0]
        colors=np.array(mesh.colors).reshape(-1,3,4)[:,0,:3]
        for tri,n,c in zip(q.reshape(-1,3,3),norms,colors):
            if np.dot(n,view)<=0:continue
            x0=max(0,int(np.floor(tri[:,0].min())));x1=min(w-1,int(np.ceil(tri[:,0].max())))
            y0=max(0,int(np.floor(tri[:,1].min())));y1=min(h-1,int(np.ceil(tri[:,1].max())))
            if x0>x1 or y0>y1:continue
            yy,xx=np.mgrid[y0:y1+1,x0:x1+1];xx=xx+.5;yy=yy+.5
            a,b,d=tri
            denom=(b[1]-d[1])*(a[0]-d[0])+(d[0]-b[0])*(a[1]-d[1])
            if abs(denom)<1e-8:continue
            wa=((b[1]-d[1])*(xx-d[0])+(d[0]-b[0])*(yy-d[1]))/denom
            wb=((d[1]-a[1])*(xx-d[0])+(a[0]-d[0])*(yy-d[1]))/denom
            wc=1-wa-wb
            z=wa*a[2]+wb*b[2]+wc*d[2]
            region=depth[y0:y1+1,x0:x1+1]
            mask=(wa>=-.0001)&(wb>=-.0001)&(wc>=-.0001)&(z>region)
            region[mask]=z[mask]
            value=np.clip(c*(.42+.66*max(0,np.dot(n,light))),0,1)
            rgb=np.where(value<=.0031308,value*12.92,1.055*value**(1/2.4)-.055)
            pix[y0:y1+1,x0:x1+1][mask]=rgb
        image=Image.fromarray((np.clip(pix,0,1)*255).astype('uint8'))
        x=(number%5)*cell_w+8;y=(number//5)*cell_h+76
        canvas.paste(image,(x,y))
        draw.text((x+8,y+h+5),name,font=font,fill='#d5e3e6')
        draw.text((x+8,y+h+25),f'{len(mesh.positions)//3} triangles',font=small,fill='#86a8b6')
    canvas.save(output)
