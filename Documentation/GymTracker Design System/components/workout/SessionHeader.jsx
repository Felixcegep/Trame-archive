import React from "react";
export function SessionHeader({title="Today\u2019s workout",elapsed,completedSets=0,totalSets=0,exercises,style}){
  const pct=totalSets>0?Math.min(100,completedSets/totalSets*100):0;
  return <div style={{padding:"16px 18px",background:"var(--tint-rest)",borderRadius:"var(--radius-section)",display:"flex",flexDirection:"column",gap:"8px",...style}}>
    <div style={{display:"flex",alignItems:"baseline",gap:"12px"}}>
      <span style={{font:"var(--type-title-medium)",whiteSpace:"nowrap",overflow:"hidden",textOverflow:"ellipsis",minWidth:0}}>{title}</span>
      <span style={{marginLeft:"auto",font:"var(--type-title-small-semibold)",fontVariantNumeric:"tabular-nums"}}>{elapsed}</span>
    </div>
    <div style={{display:"flex",font:"var(--type-footnote-medium)",color:"var(--gym-text-subdued)",fontVariantNumeric:"tabular-nums"}}>
      <span>{totalSets===0?"No exercises yet.":completedSets+" / "+totalSets+" sets"}</span>
      {exercises&&<span style={{marginLeft:"auto"}}>{exercises}</span>}
    </div>
    <div style={{height:"4px",borderRadius:"2px",background:"rgba(39,38,53,0.12)"}}><div style={{height:"100%",width:pct+"%",borderRadius:"2px",background:"var(--gym-secondary)",transition:"width var(--motion-layout)"}}></div></div>
  </div>;
}