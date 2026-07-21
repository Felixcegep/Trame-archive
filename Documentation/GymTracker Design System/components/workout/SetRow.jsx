import React from "react";
import { SetInput } from "../forms/SetInput.jsx";
import { Icon } from "../core/Icon.jsx";
export function SetRow({index,values=[],state="pending",note,locked,onToggle,onChange,style}){
  const bg=state==="completed"?"var(--gym-secondary-surface)":state==="current"?"var(--gym-current-set-surface)":"var(--gym-row-surface)";
  return <div style={{background:bg,borderRadius:"var(--radius-large)",padding:"10px 12px",...style}}>
    <div style={{display:"flex",alignItems:"center",gap:"10px"}}>
      <span style={{width:"32px",font:"var(--type-subheadline-semibold)",fontVariantNumeric:"tabular-nums",color:state==="completed"?"var(--gym-secondary)":"var(--gym-text)"}}>{index}</span>
      {values.map((v,i)=><SetInput key={i} value={v} onChange={val=>onChange&&onChange(i,val)} disabled={state==="completed"} style={{flex:1}}/>)}
      <button onClick={onToggle} className="gym-press" style={{width:"36px",height:"36px",flex:"none",border:state==="completed"?"none":"2px solid var(--gym-primary)",borderRadius:"50%",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",background:state==="completed"?"var(--gym-secondary)":"rgba(61,114,226,0.08)"}}>
        {state==="completed"&&<Icon name="checkmark" size={18} weight={700} color="#fff"/>}
      </button>
      <span style={{width:"20px",display:"flex",justifyContent:"center"}}>{state==="completed"?(locked&&<Icon name="lock" size={14} color="var(--gym-text-subtle)"/>):<Icon name="ellipsis" size={16} color="var(--gym-text-subtle)"/>}</span>
    </div>
    {note&&<div style={{font:"var(--type-caption)",color:"var(--gym-text-subdued)",padding:"8px 4px 0 42px"}}>{note}</div>}
  </div>;
}