import React from "react";
import { Icon } from "./Icon.jsx";
export function SectionLabel({children,icon,iconColor="var(--gym-secondary)",detail,trailing,color="var(--gym-text-subdued)",style}){
  return <div style={{display:"flex",alignItems:"center",gap:"8px",...style}}>
    {icon&&<Icon name={icon} size={13} weight={700} color={iconColor}/>}
    <span style={{font:"var(--type-caption-bold)",letterSpacing:"var(--tracking-label)",color,textTransform:"uppercase"}}>{children}</span>
    {detail&&<span style={{font:"var(--type-caption)",color:"var(--gym-text-subdued)"}}>{detail}</span>}
    {trailing&&<div style={{marginLeft:"auto"}}>{trailing}</div>}
  </div>;
}