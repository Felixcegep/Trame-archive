import React from "react";
export function SegmentedControl({options,value,onChange,style}){
  return <div style={{display:"flex",background:"rgba(39,38,53,0.08)",borderRadius:"var(--radius-pill)",padding:"2px",...style}}>
    {options.map(opt=>{const key=typeof opt==="string"?opt:opt.value;const label=typeof opt==="string"?opt:opt.label;const active=key===value;
    return <button key={key} onClick={()=>onChange&&onChange(key)} style={{flex:1,border:"none",cursor:"pointer",font:active?"var(--type-subheadline-semibold)":"var(--type-subheadline)",color:"var(--gym-text)",background:active?"#fff":"none",borderRadius:"var(--radius-pill)",padding:"8px 10px",boxShadow:active?"0 2px 6px rgba(39,38,53,0.10)":"none",transition:"background var(--motion-compact)",whiteSpace:"nowrap"}}>{label}</button>;})}
  </div>;
}