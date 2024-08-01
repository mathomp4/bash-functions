# vim: ft=bash 
function dropin () {
   JOBID=$1
   # We need to grab the number of tasks from the
   # job id so we can use that with srun
   NUMTASKS=$(scontrol show job $JOBID | rg -o 'NumTasks=\d+' | cut -d= -f2)
   srun -n $NUMTASKS --pty --jobid=$JOBID bash
}
