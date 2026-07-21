const {TabBar}=window.GymTrackerDesignSystem_9b15a7;
function GymApp(){
  const [tab,setTab]=React.useState("today");
  const TABS=[{key:"today",icon:"home",label:"Today"},{key:"train",icon:"folders",label:"Train"},{key:"nutrition",icon:"nutrition",label:"Nutrition"},{key:"progress",icon:"history",label:"Progress"}];
  const [workingOut,setWorkingOut]=React.useState(false);
  const [hasHistory,setHasHistory]=React.useState(false);
  return <div style={{maxWidth:430,height:"100%",minHeight:700,margin:"0 auto",position:"relative",display:"flex",flexDirection:"column",overflow:"hidden",background:"var(--surface-page)",font:"var(--type-body)",color:"var(--text-body)"}}>
    <StatusBar/>
    <div style={{flex:1,overflowY:"auto"}}>
      {tab==="today"&&<HomeScreen onStartWorkout={()=>setWorkingOut(true)} hasHistory={hasHistory}/>}
      {tab==="train"&&<LibraryScreen/>}
      {tab==="progress"&&<HistoryScreen/>}
      {tab==="nutrition"&&<div style={{display:"flex",flexDirection:"column",gap:12,padding:"40px 20px",color:"var(--gym-text-subdued)",font:"var(--type-subheadline)"}}><div style={{font:"var(--type-display-medium)",color:"var(--gym-text)"}}>Nutrition</div>Wave 1 surface — see the “Nutrition (wave 1)” template for the full mock.</div>}
    </div>
    <div style={{position:"absolute",left:16,right:16,bottom:16}}><TabBar tabs={TABS} active={tab} onChange={setTab}/></div>
    {workingOut&&<div style={{position:"absolute",inset:0,background:"var(--surface-page)",display:"flex",flexDirection:"column"}}>
      <StatusBar/>
      <div style={{flex:1,minHeight:0}}><ActiveWorkoutScreen onClose={()=>setWorkingOut(false)} onFinish={()=>{setWorkingOut(false);setHasHistory(true);}}/></div>
    </div>}
  </div>;
}
window.GymApp = GymApp;
