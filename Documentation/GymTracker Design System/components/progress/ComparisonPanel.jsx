import React from "react";
export function ComparisonPanel({title="Program vs performed",met=true,planned,performed,suggested,checks=[],style}){
  return <div style={{background:met?"var(--gym-secondary-surface)":"var(--gym-accent-surface)",borderRadius:"var(--radius-large)",padding:"16px",...style}}>
    <div style={{display:"flex",justifyContent:"space-between",alignItems:"center"}}>
      <span style={{font:"var(--type-headline)"}}>{title}</span>
      <span style={{display:"inline-flex",alignItems:"center",gap:"6px",font:"var(--type-caption-bold)",color:met?"var(--gym-secondary)":"var(--gym-accent)"}}>
        <span style={{width:"18px",height:"18px",borderRadius:"50%",background:met?"var(--gym-secondary)":"var(--gym-accent)",color:"#fff",display:"inline-flex",alignItems:"center",justifyContent:"center",fontSize:"11px"}}>{met?"✓":"!"}</span>
        {met?"Met":"Missed"}
      </span>
    </div>
    <div style={{marginTop:"10px",display:"flex",flexDirection:"column",gap:"4px"}}>
      <div style={{display:"flex",justifyContent:"space-between",font:"var(--type-body)"}}><span style={{color:"var(--gym-text-subdued)"}}>Planned</span><b>{planned}</b></div>
      <div style={{display:"flex",justifyContent:"space-between",font:"var(--type-body)"}}><span style={{color:"var(--gym-text-subdued)"}}>Performed</span><b>{performed}</b></div>
      {suggested&&<div style={{display:"flex",justifyContent:"space-between",font:"var(--type-body)"}}><span style={{color:"var(--gym-text-subdued)"}}>Suggested</span><b>{suggested}</b></div>}
    </div>
    {checks.length>0&&<div style={{display:"flex",gap:"14px",marginTop:"12px",flexWrap:"wrap"}}>
      {checks.map(c=><span key={c} style={{display:"inline-flex",alignItems:"center",gap:"5px",font:"var(--type-caption-bold)",color:"var(--gym-secondary)"}}><span style={{width:"14px",height:"14px",borderRadius:"50%",background:"var(--gym-secondary)",color:"#fff",display:"inline-flex",alignItems:"center",justifyContent:"center",fontSize:"9px"}}>✓</span>{c}</span>)}
    </div>}
  </div>;
}
