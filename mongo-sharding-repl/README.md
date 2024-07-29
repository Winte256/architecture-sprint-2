## Как запустить

Запускаем mongodb, redis и приложение

```shell
docker compose up -d
```

Инициализируем контейнеры

```shell
./scripts/mongo-init.sh
```

## Как проверить

### Если вы запускаете проект на локальной машине

Откройте в браузере http://localhost:8080

## Доступные эндпоинты

Список доступных эндпоинтов, swagger http://localhost:8080/docs