import React from "react";
export function SetInput({value,onChange,width="100%",disabled,style}){
  return <input inputMode="decimal" value={value} disabled={disabled} onChange={e=>onChange&&onChange(e.target.value)}
  style={{width,boxSizing:"border-box",border:"none",outline:"none",textAlign:"center",font:"600 22px var(--font-body)",fontVariantNumeric:"tabular-nums",color:"var(--gym-text)",background:"var(--surface-card)",borderRadius:"var(--radius-medium)",padding:"12px 8px",opacity:disabled?0.6:1,...style}}/>;
}