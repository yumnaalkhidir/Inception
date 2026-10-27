all: build up 

up:
	cd srcs && docker-compose up -d

down:
	cd srcs && docker-compose down

build:
	mkdir -p /home/${USER}/data/mariadb
	mkdir -p /home/${USER}/data/wordpress
	cd srcs && docker-compose build

clean: down
	- docker rmi -f $(docker images -q)

re: clean all

fclean:
	-docker stop $$(docker ps -qa)
	-docker rm -f nginx wordpress mariadb
	-docker volume rm srcs_mariadb srcs_wordpress
	-docker rmi -f $$(docker images -qa)
	-docker network rm $$(docker network ls -q) 2>/dev/null
	-sudo rm -rf /home/$${USER}/data
	-yes | docker system prune -a --volumes

.PHONY: up down build clean re  
