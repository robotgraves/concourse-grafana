#!/usr/bin/env bash
set -x -e


### ADJUST THIS SECTION DEPENDING ON HOST MACHINE CONTAINING FLY OR NOT ###
#wget -O /tmp/fly https://github.com/concourse/concourse/releases/download/v3.2.1/fly_linux_amd64
#mv /tmp/fly /usr/local/bin/fly
#chmod +x /usr/local/bin/fly
#which fly

### ADJUST THIS SECTION TO LOG INTO THE APPROPRIATE CONCOURSE (use -n for team name)
#fly -t test login -c http://10.0.2.15:8080 -u concourse -p changeme


### ADJUST THIS SECTION FOR THE APPROPRIATE CONTAINER NAME ###
export CONTAINER_NAME=concoursegrafana_concourse-worker_1
export COMPOSE_NAME=concourse-worker
##############################################################


export CONTAINER="$(docker ps -aqf 'name='$CONTAINER_NAME'')"
export OUTPUT="$(fly -t test workers | grep $CONTAINER)"
# CHECK TO MAKE SURE THAT THE WORKER IS CURRENTLY RUNNING #
if echo $OUTPUT | grep "running"; then
    docker exec $CONTAINER_NAME concourse retire-worker --name $CONTAINER
    x=0
    # LOOP ON CLOSING PROCEDURES #
    while [ $x -eq 0 ]
    do
        export OUTPUT="$(fly -t test workers | grep $CONTAINER)"
        if echo $OUTPUT | grep "running"; then
            echo "still running, shutting down soon"
            sleep 1
        elif echo $OUTPUT | grep "retiring"; then
            echo "retiring, shutting down soon"
            sleep 1
        elif [ -z "$OUTPUT" ]; then
            echo "worker has shut down"
            x=1
        else
            exit 1
            x=1
        fi
    done
fi
# CLEAN UP CONTAINER AND VOLUMES, AND FOLLOW UP WITH RESTARTING THE CONTAINER #
docker volume rm $(docker volume ls -f dangling=true -q)
docker-compose up --no-recreate --no-deps -d $COMPOSE_NAME