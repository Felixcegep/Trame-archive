import React from "react";
import { Icon } from "../core/Icon.jsx";
const DEFAULT_TABS=[{key:"today",icon:"home",label:"Today"},{key:"train",icon:"folders",label:"Train"},{key:"nutrition",icon:"nutrition",label:"Nutrition"},{key:"progress",icon:"history",label:"Progress"}];
export function TabBar({tabs=DEFAULT_TABS,active="today",onChange,style}){
  return <div style={{display:"flex",background:"var(--surface-card)",borderRadius:"var(--radius-pill)",padding:"6px",boxShadow:"0 6px 20px rgba(39,38,53,0.08)",...style}}>
    {tabs.map(t=>{const sel=t.key===active;
    return <button key={t.key} onClick={()=>onChange&&onChange(t.key)} className="gym-press" style={{flex:1,display:"flex",flexDirection:"column",alignItems:"center",gap:"3px",border:"none",cursor:"pointer",background:sel?"var(--gym-row-surface)":"none",borderRadius:"var(--radius-pill)",padding:"9px 6px"}}>
      <Icon name={t.icon} size={24} color={sel&&t.key!=="today"?"var(--gym-primary)":"var(--gym-text)"}/>
      <span style={{font:"var(--type-caption2-bold)",color:sel&&t.key!=="today"?"var(--gym-primary)":"var(--gym-text)"}}>{t.label}</span>
    </button>;})}
  </div>;
}