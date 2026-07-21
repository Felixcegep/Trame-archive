
const StatusBar=({dark})=>(
  <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",padding:"14px 24px 6px",font:"600 15px var(--font-body)",fontVariantNumeric:"tabular-nums",color:"var(--gym-text)"}}>
    <span>7:34</span>
    <span style={{display:"flex",gap:6,alignItems:"center"}}>
      <span className="material-symbols-rounded" style={{fontSize:16}}>signal_cellular_alt</span>
      <span className="material-symbols-rounded" style={{fontSize:16}}>wifi</span>
      <span className="material-symbols-rounded" style={{fontSize:18}}>battery_full_alt</span>
    </span>
  </div>);
const CircleButton=({icon,color,onClick})=>{
  const {Icon}=window.GymTrackerDesignSystem_9b15a7;
  return <button className="gym-press" onClick={onClick} style={{width:52,height:52,border:"none",borderRadius:"50%",background:"var(--surface-card)",boxShadow:"var(--shadow-card)",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center"}}>
    <Icon name={icon} size={22} weight={600} color={color||"var(--gym-text)"}/>
  </button>;};
Object.assign(window,{StatusBar,CircleButton});
