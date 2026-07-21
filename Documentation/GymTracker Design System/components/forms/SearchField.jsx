import React from "react";
import { Icon } from "../core/Icon.jsx";
export function SearchField({value,onChange,placeholder="Search your library",style}){
  return <div style={{display:"flex",alignItems:"center",gap:"8px",height:"46px",padding:"0 12px",background:"var(--surface-card)",borderRadius:"14px",boxSizing:"border-box",...style}}>
    <Icon name="search" size={18} filled={false} color="var(--gym-text-subdued)"/>
    <input value={value} onChange={e=>onChange&&onChange(e.target.value)} placeholder={placeholder} style={{flex:1,border:"none",outline:"none",background:"none",font:"var(--type-body)",color:"var(--gym-text)"}}/>
  </div>;
}