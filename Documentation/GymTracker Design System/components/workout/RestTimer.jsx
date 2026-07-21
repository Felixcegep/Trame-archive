import React from "react";
import { IconChip } from "../core/IconChip.jsx";
import { Button } from "../core/Button.jsx";
import { Icon } from "../core/Icon.jsx";
export function RestTimer({state="running",remaining,onAddTime,onPauseResume,onSkip,onContinue,style}){
  const msg=state==="ready"?"Rest complete. Your next set is ready.":state==="paused"?"Rest paused.":"Take a breath. Your next set is ready when you are.";
  return <div style={{padding:"16px 18px",background:"var(--tint-rest)",borderRadius:"var(--radius-section)",display:"flex",flexDirection:"column",gap:"12px",...style}}>
    <div style={{display:"flex",alignItems:"center",gap:"8px"}}>
      <IconChip icon="timer" color="accent" size={42} surface style={{background:"rgba(255,252,247,0.8)"}}/>
      <div style={{flex:1,minWidth:0}}>
        <div style={{font:"var(--type-subheadline-semibold)"}}>Rest between sets</div>
        <div style={{font:"var(--type-caption)",color:"var(--gym-text-subdued)"}}>{msg}</div>
      </div>
      {state==="ready"
        ?<span style={{font:"var(--type-title-small-semibold)",color:"var(--gym-secondary)"}}>Ready</span>
        :<span style={{font:"var(--type-title-small-semibold)",fontVariantNumeric:"tabular-nums",color:"var(--gym-accent)"}}>{remaining}</span>}
    </div>
    {state==="ready"
      ?<Button variant="prominent" onClick={onContinue} style={{padding:"12px"}}>Continue workout</Button>
      :<div style={{display:"flex",gap:"8px",alignItems:"center"}}>
        <button className="gym-press" onClick={()=>onAddTime&&onAddTime(15)} style={{font:"var(--type-subheadline-semibold)",color:"var(--gym-text)",background:"var(--tint-rest-chip)",border:"none",borderRadius:"999px",padding:"9px 18px",cursor:"pointer"}}>+15s</button>
        <button className="gym-press" onClick={()=>onAddTime&&onAddTime(30)} style={{font:"var(--type-subheadline-semibold)",color:"var(--gym-text)",background:"var(--tint-rest-chip)",border:"none",borderRadius:"999px",padding:"9px 18px",cursor:"pointer"}}>+30s</button>
        <div style={{flex:1}}></div>
        <button className="gym-press" onClick={onPauseResume} style={{width:"42px",height:"42px",borderRadius:"50%",background:"var(--tint-rest-chip)",border:"none",display:"flex",alignItems:"center",justifyContent:"center",cursor:"pointer"}}><Icon name={state==="paused"?"play":"pause"} size={15} color="var(--gym-text)"/></button>
        <button className="gym-press" onClick={onSkip} style={{width:"42px",height:"42px",borderRadius:"50%",background:"var(--tint-rest-chip)",border:"none",display:"flex",alignItems:"center",justifyContent:"center",cursor:"pointer"}}><Icon name="skip" size={15} color="var(--gym-text)"/></button>
      </div>}
  </div>;
}