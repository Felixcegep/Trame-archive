import React from "react";
const STATUS={
  completed:{label:"Completed",color:"var(--gym-secondary)",icon:"✓"},
  skipped:{label:"Skipped",color:"var(--gym-text-subdued)",icon:"○"},
  missed:{label:"Missed",color:"var(--gym-accent)",icon:"⚠"},
  "in-progress":{label:"In progress",color:"var(--gym-primary)",icon:"▸"},
  ready:{label:"Ready",color:"var(--gym-primary)",icon:"●"},
  scheduled:{label:"Scheduled",color:"var(--gym-text-subdued)",icon:"○"}
};
export function StatusRow({title,detail,status,isToday,style}){
  const s=STATUS[status]||STATUS.scheduled;
  return <div style={{display:"flex",alignItems:"center",gap:"14px",padding:"12px 0",...style}}>
    <div style={{flex:1,minWidth:0}}>
      <div style={{font:"var(--type-headline)",color:isToday?"var(--gym-primary)":"var(--gym-text)"}}>{title}</div>
      {detail&&<div style={{font:"var(--type-caption)",color:"var(--gym-text-subdued)",marginTop:"2px"}}>{detail}</div>}
    </div>
    <span style={{display:"inline-flex",alignItems:"center",gap:"6px",font:"var(--type-caption-bold)",color:s.color}}>
      <span>{s.icon}</span>{s.label}
    </span>
    <span style={{color:"var(--gym-text-subdued)",fontSize:"15px"}}>›</span>
  </div>;
}
