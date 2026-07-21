import React from "react";
import { Icon } from "../core/Icon.jsx";
import { Button } from "../core/Button.jsx";
export function ExerciseCard({name,state="collapsed",columns=["Reps","Weight (kg)"],prescription,lastTime,completedSets=0,totalSets=0,elapsed,children,onAddSet,onClick,style}){
  const current=state==="current";const done=state==="completed";
  return <div className={onClick?"gym-press":undefined} onClick={onClick} style={{background:done?"var(--gym-secondary-surface)":current?"var(--gym-current-set-surface)":"var(--surface-card)",border:current?"var(--border-focus)":"var(--border-hairline)",borderRadius:"var(--radius-card)",padding:current?"16px":"12px",cursor:onClick?"pointer":undefined,...style}}>
    <div style={{display:"flex",alignItems:"flex-start",gap:"12px"}}>
      {done&&<Icon name="checkmarkCircle" size={22} color="var(--gym-secondary)" style={{marginTop:"2px"}}/>}
      <div style={{flex:1,minWidth:0,display:"flex",flexDirection:"column",gap:"4px"}}>
        {current&&<span style={{display:"inline-flex",alignItems:"center",gap:"6px",font:"var(--type-caption2-bold)",letterSpacing:"var(--tracking-label-tight)",color:"var(--gym-primary)",textTransform:"uppercase"}}><Icon name="circleFill" size={9} color="var(--gym-primary)"/>Current exercise</span>}
        <span style={{font:current?"var(--type-title-small)":"var(--type-headline)"}}>{name}</span>
        {prescription&&<span style={{font:"var(--type-caption-bold)",fontVariantNumeric:"tabular-nums",color:"var(--gym-primary)"}}>{prescription}</span>}
        {lastTime&&<span style={{font:"var(--type-caption)",color:"var(--gym-text-subdued)"}}>{lastTime}</span>}
        <span style={{font:"var(--type-caption)",fontVariantNumeric:"tabular-nums",color:"var(--gym-text-subdued)"}}>{completedSets}/{totalSets} sets{elapsed?" \u2022 "+elapsed:""}</span>
      </div>
      <div style={{display:"flex",alignItems:"center",gap:"8px"}}>
        <span style={{width:"30px",height:"30px",display:"flex",alignItems:"center",justifyContent:"center",borderRadius:"50%",background:"rgba(39,38,53,0.06)"}}><Icon name="ellipsis" size={16} color="var(--gym-text-subdued)"/></span>
        <Icon name="chevronDown" size={18} weight={600} color="var(--gym-text-subdued)" style={{transform:current?"none":"rotate(-90deg)"}}/>
      </div>
    </div>
    {current&&children&&<div style={{marginTop:"12px",display:"flex",flexDirection:"column",gap:"6px"}}>
      <div style={{display:"flex",gap:"10px",padding:"0 12px",font:"var(--type-caption2-bold)",letterSpacing:"var(--tracking-label-tight)",color:"var(--gym-text-subdued)",textTransform:"uppercase"}}>
        <span style={{width:"32px"}}>Set</span>
        {columns.map(c=><span key={c} style={{flex:1,textAlign:"center"}}>{c}</span>)}
        <span style={{width:"64px"}}></span>
      </div>
      {children}
      {onAddSet&&<Button variant="text" icon="plus" onClick={onAddSet} style={{alignSelf:"flex-start"}}>Add set</Button>}
    </div>}
  </div>;
}