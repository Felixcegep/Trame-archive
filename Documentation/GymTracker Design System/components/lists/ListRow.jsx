import React from "react";
import { IconChip } from "../core/IconChip.jsx";
import { Icon } from "../core/Icon.jsx";
export function ListRow({icon,color="primary",surface=true,title,subtitle,count,trailing,chevron=true,card=true,size=42,onClick,style}){
  return <div className={onClick?"gym-press":undefined} onClick={onClick} style={{display:"flex",alignItems:"center",gap:"12px",padding:card?"14px":"10px 14px",background:card?"var(--surface-card)":"none",border:card?"var(--border-hairline)":"none",borderRadius:card?"var(--radius-large)":"0",boxShadow:card?"var(--shadow-row)":"none",cursor:onClick?"pointer":undefined,...style}}>
    {icon&&<IconChip icon={icon} color={color} shape={size>=40?"rounded":"rounded"} size={size} surface={surface}/>}
    <div style={{flex:1,minWidth:0}}>
      <div style={{font:"var(--type-body-medium)",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{title}</div>
      {subtitle&&<div style={{font:"var(--type-caption)",color:"var(--gym-text-subdued)",marginTop:"2px"}}>{subtitle}</div>}
    </div>
    {count!=null&&<span style={{font:"var(--type-subheadline)",fontVariantNumeric:"tabular-nums",color:"var(--gym-text-subdued)"}}>{count}</span>}
    {trailing}
    {chevron&&<Icon name="chevronRight" size={14} weight={700} color="var(--gym-text-subtle)"/>}
  </div>;
}