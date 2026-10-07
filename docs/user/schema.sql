-- UserDB: проектная схема, не миграция существующей БД.
-- Выполнять целиком в пустой изолированной PostgreSQL-базе.
BEGIN;
CREATE SCHEMA user_service;

CREATE TABLE user_service.user_profile (
    id uuid PRIMARY KEY,
    first_name text NOT NULL,
    last_name text NOT NULL,
    email text NOT NULL,
    address text NOT NULL,
    payment_account_id uuid NOT NULL,
    role text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT user_profile_email_unique UNIQUE (email)
);

COMMENT ON SCHEMA user_service IS 'Профили User Service; отдельная UserDB.';
COMMENT ON TABLE user_service.user_profile IS 'Полные профили покупателей и продавцов в одной таблице; без истории изменений.';
COMMENT ON COLUMN user_service.user_profile.id IS 'UUID Keycloak и профиля совпадают; задаётся явно, не генерируется БД.';
COMMENT ON COLUMN user_service.user_profile.first_name IS 'Обязательное имя; отчество не хранится.';
COMMENT ON COLUMN user_service.user_profile.last_name IS 'Обязательная фамилия.';
COMMENT ON COLUMN user_service.user_profile.email IS 'Email в нижнем регистре без пробельных символов, уникален для всех ролей; должен совпадать с Keycloak.';
COMMENT ON COLUMN user_service.user_profile.address IS 'Один адрес: доставка для BUYER, отправка/возврат товара для SELLER.';
COMMENT ON COLUMN user_service.user_profile.payment_account_id IS 'UUID счёта Payment Service; может повторяться у любых профилей. Без межбазового FK.';
COMMENT ON COLUMN user_service.user_profile.role IS 'BUYER или SELLER; неизменяема, должна соответствовать Keycloak.';
COMMENT ON COLUMN user_service.user_profile.created_at IS 'Время создания профиля, сохраняется при UPDATE.';
COMMENT ON COLUMN user_service.user_profile.updated_at IS 'Время последнего фактического изменения; повтор без изменения данных не меняет время.';
COMMIT;
