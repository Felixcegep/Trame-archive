
function HistoryScreen(){
  const {SegmentedControl,HistoryRow,IconChip}=window.GymTrackerDesignSystem_9b15a7;
  const [tab,setTab]=React.useState("Workouts");
  return <div style={{display:"flex",flexDirection:"column",gap:16,padding:"40px 20px 120px"}}>
    <div style={{font:"var(--type-display-medium)"}}>Progress</div>
    <SegmentedControl options={["Workouts","Charts","Records","Balance"]} value={tab} onChange={setTab}/>
    {tab==="Workouts"?<React.Fragment>
      <div style={{font:"var(--type-title-small-semibold)",color:"var(--gym-text-subdued)"}}>Today</div>
      <HistoryRow title="Upper Body" date="Today, 5:11 PM" duration="59 min" exercises="1 exercise" sets="3 sets" onClick={()=>{}}/>
    </React.Fragment>
    :<div style={{display:"flex",flexDirection:"column",alignItems:"center",gap:10,padding:"64px 24px",textAlign:"center"}}>
      <IconChip icon={tab==="Records"?"trophy":tab==="Balance"?"chart":"progression"} color="accent" size={52}/>
      <div style={{font:"var(--type-headline)"}}>{tab} needs more data</div>
      <div style={{font:"var(--type-subheadline)",color:"var(--gym-text-subdued)"}}>Complete more workouts to unlock {tab.toLowerCase()} insights.</div>
    </div>}
  </div>;
}
window.HistoryScreen=HistoryScreen;
