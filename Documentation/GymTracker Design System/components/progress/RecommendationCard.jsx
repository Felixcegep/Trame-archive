import React from "react";
import { Icon } from "../core/Icon.jsx";
export function RecommendationCard({exercise,rationale,acceptLabel,keepLabel,onAccept,onKeep,onEdit,style}){
  return <div style={{background:"var(--gym-surface-card)",border:"1px solid var(--gym-primary-border,rgba(61,114,226,0.28))",borderRadius:"var(--radius-card)",padding:"18px 18px 14px",...style}}>
    <div style={{display:"flex",alignItems:"center",gap:8,font:"var(--type-caption-bold)",letterSpacing:"var(--tracking-label)",color:"var(--gym-primary)"}}>
      <Icon name="progression" size={17} color="var(--gym-primary)"/>Progression recommendation
    </div>
    <div style={{font:"var(--type-title-medium)",margin:"12px 0 8px"}}>{exercise}</div>
    <div style={{font:"var(--type-body)",color:"var(--gym-text)",marginBottom:"16px"}}>{rationale}</div>
    <div style={{display:"flex",gap:"12px"}}>
      <button className="gym-press" onClick={onAccept} style={{flex:1,font:"var(--type-headline)",color:"#fff",background:"var(--gym-primary)",border:"none",borderRadius:"999px",padding:"14px",cursor:"pointer"}}>{acceptLabel}</button>
      <button className="gym-press" onClick={onKeep} style={{flex:1,font:"var(--type-headline)",color:"var(--gym-text)",background:"var(--tint-current,#E7ECF8)",border:"none",borderRadius:"999px",padding:"14px",cursor:"pointer"}}>{keepLabel}</button>
    </div>
    <button className="gym-press" onClick={onEdit} style={{width:"100%",font:"var(--type-headline)",color:"var(--gym-text)",background:"none",border:"none",padding:"14px 0 4px",cursor:"pointer"}}>Edit manually</button>
  </div>;
}
