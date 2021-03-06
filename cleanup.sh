#!/usr/bin/env bash

echo "starting cleanup"
### ADJUST THIS SECTION DEPENDING ON HOST MACHINE CONTAINING FLY OR NOT ###
#wget -O /tmp/fly https://github.com/concourse/concourse/releases/download/v3.2.1/fly_linux_amd64
#mv /tmp/fly /usr/local/bin/fly
#chmod +x /usr/local/bin/fly
#which fly

### ADJUST THIS SECTION TO LOG INTO THE APPROPRIATE CONCOURSE (use -n for team name)
#fly -t test login -c http://10.0.2.15:8080 -u concourse -p changeme
fly -t test sync

### ADJUST THIS SECTION FOR THE APPROPRIATE CONTAINER NAME ###
export CONTAINER_NAME=concoursegrafana_concourse-worker_1
export COMPOSE_NAME=concourse-worker
export COMPOSE_FILE=docker-compose.yml
##############################################################


export CONTAINER="$(docker ps -aqf 'name='$CONTAINER_NAME'')"
export OUTPUT="$(fly -t test workers | grep $CONTAINER)"
# CHECK TO MAKE SURE THAT THE WORKER IS CURRENTLY RUNNING #
if echo $OUTPUT | grep "running"; then
    export OUTPUT="$(docker exec $CONTAINER_NAME concourse retire-worker --name $CONTAINER)"
    if echo $OUTPUT | grep "connection error"; then
        echo "docker is dead, rebooting on first try"
        killall -9 dockerd
        docker ps -aq --no-trunc | xargs docker rm
    elif echo $OUTPUT | grep "connection refused"; then
        echo "docker is nonresponsive, rebooting on first try"
        docker kill $CONTAINER
    fi
    sleep 2
    x=0
    # LOOP ON CLOSING PROCEDURES #
    while [ $x -eq 0 ]
    do
        export OUTPUT="$(fly -t test workers | grep $CONTAINER)"
        if echo $OUTPUT | grep "running"; then
            echo "still running, shutting down soon"
            export OUTPUT="$(docker exec $CONTAINER_NAME concourse retire-worker --name $CONTAINER)"
            if echo $OUTPUT | grep "connection error"; then
                echo "docker is dead, rebooting inside loop"
                killall -9 dockerd
                docker ps -aq --no-trunc | xargs docker rm
            elif echo $OUTPUT | grep "connection refused"; then
                echo "docker is nonresponsive, rebooting inside loop"
                docker kill $CONTAINER
            fi
            sleep 2
        elif echo $OUTPUT | grep "retiring"; then
            echo "retiring, shutting down soon"
            sleep 2
        elif [ -z "$OUTPUT" ]; then
            echo "worker has shut down"
            x=1
        else
            exit 1
            x=1
        fi
    done
    sleep 2
elif [ -z $CONTAINER ]; then
    echo "container was dead before we started"
else
    echo "something is wrong"
    exit 1
fi
x=0
while [ $x -eq 0 ]
# LOOP ON CLOSING PROCEDURES #
do
    export CONTAINER="$(docker ps -aqf 'name='$CONTAINER_NAME'')"
    if [ -z "$CONTAINER" ]; then
        echo "container has shut down"
        x=1
        sleep 2
    else
        echo "container has not shut down"
        docker rm $CONTAINER_NAME || true
        sleep 2
    fi
done
# CLEAN UP CONTAINER AND VOLUMES, AND FOLLOW UP WITH RESTARTING THE CONTAINER #
docker volume rm $(docker volume ls -f dangling=true -q) || true
docker-compose up -f "$COMPOSE_FILE" --no-recreate --no-deps -d "$COMPOSE_NAME"
export OUTPUT="$(fly -t test workers | grep stalled)"
if echo $OUTPUT | grep "retiring"; then
    OUTPUT=($OUTPUT)
    STALLED=${OUTPUT[0]}
    fly -t test prune-worker -w $STALLED
fi
echo "cleanup finished"
