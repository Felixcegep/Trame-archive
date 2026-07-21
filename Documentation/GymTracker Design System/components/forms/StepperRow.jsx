import React from "react";
import { Icon } from "../core/Icon.jsx";
export function StepperRow({label,variant="stepper",value,on,onIncrement,onDecrement,onToggle,onPress,last,style}){
  const row={display:"flex",alignItems:"center",justifyContent:"space-between",gap:"12px",padding:"16px 16px",borderBottom:last?"none":"1px solid var(--gym-hairline,rgba(39,38,53,0.08))",...style};
  const lbl=<span style={{font:"var(--type-body)",color:"var(--gym-text)"}}>{label}{variant==="stepper"&&value!==undefined?": "+value:""}</span>;
  if(variant==="toggle"){
    return <div style={row}>{lbl}
      <button className="gym-press" role="switch" aria-checked={!!on} onClick={()=>onToggle&&onToggle(!on)} style={{width:"51px",height:"31px",borderRadius:"999px",border:"none",padding:"2px",background:on?"var(--gym-secondary)":"rgba(39,38,53,0.18)",display:"flex",justifyContent:on?"flex-end":"flex-start",cursor:"pointer",transition:"background .15s"}}>
        <span style={{width:"27px",height:"27px",borderRadius:"50%",background:"#fff",boxShadow:"0 1px 3px rgba(0,0,0,0.2)"}}></span>
      </button></div>;
  }
  if(variant==="picker"){
    return <button className="gym-press" onClick={onPress} style={{...row,width:"100%",background:"none",border:"none",borderBottom:row.borderBottom,textAlign:"left",cursor:"pointer",font:"inherit"}}>{lbl}
      <span style={{display:"flex",alignItems:"center",gap:"6px",font:"var(--type-body)",color:"var(--gym-text-subdued)"}}>{value}<Icon name="picker" size={17} color="var(--gym-text-subdued)"/></span>
    </button>;
  }
  return <div style={row}>{lbl}
    <div style={{display:"flex",alignItems:"center",background:"var(--gym-fill-secondary,rgba(39,38,53,0.06))",borderRadius:"999px"}}>
      <button className="gym-press" aria-label="Decrease" onClick={onDecrement} style={{width:"52px",height:"38px",background:"none",border:"none",display:"flex",alignItems:"center",justifyContent:"center",cursor:"pointer",borderRadius:"999px 0 0 999px"}}><Icon name="minus" size={18} color="var(--gym-text)"/></button>
      <span style={{width:"1px",height:"20px",background:"rgba(39,38,53,0.15)"}}></span>
      <button className="gym-press" aria-label="Increase" onClick={onIncrement} style={{width:"52px",height:"38px",background:"none",border:"none",display:"flex",alignItems:"center",justifyContent:"center",cursor:"pointer",borderRadius:"0 999px 999px 0"}}><Icon name="plus" size={18} color="var(--gym-text)"/></button>
    </div>
  </div>;
}
