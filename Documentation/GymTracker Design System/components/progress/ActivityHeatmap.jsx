import React from "react";
const LEVELS=["var(--gym-row-surface)","rgba(72,122,108,0.22)","rgba(72,122,108,0.45)","rgba(72,122,108,0.72)","var(--gym-secondary)"];
export function ActivityHeatmap({weeks=[],monthLabels=[],title,subtitle,cell=11,gap=3,legend=true,style}){
  const step=cell+gap;
  return <div style={{background:"var(--surface-card)",border:"var(--border-hairline)",borderRadius:"var(--radius-large)",boxShadow:"var(--shadow-row)",padding:"16px",...style}}>
    {(title||subtitle)&&<div style={{display:"flex",alignItems:"baseline",gap:"10px",marginBottom:"12px"}}>
      {title&&<span style={{font:"var(--type-headline)"}}>{title}</span>}
      {subtitle&&<span style={{font:"var(--type-caption)",color:"var(--gym-text-subdued)"}}>{subtitle}</span>}
    </div>}
    <div style={{overflowX:"auto"}}>
      <div style={{position:"relative",paddingTop:"16px",paddingLeft:"30px",width:`${30+weeks.length*step}px`}}>
        {monthLabels.map((m,i)=><span key={i} style={{position:"absolute",top:0,left:`${30+m.week*step}px`,font:"var(--type-caption)",color:"var(--gym-text-subdued)"}}>{m.label}</span>)}
        {["Lun","Mer","Ven"].map((d,i)=><span key={d} style={{position:"absolute",left:0,top:`${16+(i*2)*step}px`,font:"var(--type-caption)",color:"var(--gym-text-subtle)",lineHeight:`${cell}px`}}>{d}</span>)}
        <div style={{display:"flex",gap:`${gap}px`}}>
          {weeks.map((col,w)=><div key={w} style={{display:"flex",flexDirection:"column",gap:`${gap}px`}}>
            {col.map((lv,d)=><div key={d} title={lv>0?`${lv} session${lv>1?"s":""}`:undefined} style={{width:`${cell}px`,height:`${cell}px`,borderRadius:"3px",background:LEVELS[Math.max(0,Math.min(4,lv||0))]}}></div>)}
          </div>)}
        </div>
      </div>
    </div>
    {legend&&<div style={{display:"flex",alignItems:"center",gap:"4px",justifyContent:"flex-end",marginTop:"10px",font:"var(--type-caption)",color:"var(--gym-text-subdued)"}}>
      Moins {LEVELS.map((c,i)=><span key={i} style={{width:"10px",height:"10px",borderRadius:"3px",background:c,display:"inline-block"}}></span>)} Plus
    </div>}
  </div>;
}
