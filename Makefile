COMPOSE      := cd srcs && docker-compose
DATA_DIR     := /home/$(USER)/data
SUB_DATA_DIRS    := $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

all: build up 

$(SUB_DATA_DIRS):
	mkdir -p $@


build: $(SUB_DATA_DIRS)
	$(COMPOSE) build

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

clean: 
	$(COMPOSE) down --rmi all

fclean:
	$(COMPOSE) down -v --rmi all
	sudo rm -rf $(DATA_DIR)


re: fclean all

.PHONY: up down build clean re  
