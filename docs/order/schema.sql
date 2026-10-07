-- OrderDB: проект бизнес-схемы; не миграция существующей БД.
-- Только для пустой изолированной PostgreSQL-базы. Таблицы Camunda не включены.
BEGIN;
CREATE SCHEMA order_service;

CREATE TABLE order_service.orders (
    id uuid PRIMARY KEY,
    buyer_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity bigint NOT NULL,
    seller_id uuid,
    product_name text,
    category_id uuid,
    category_name text,
    product_description jsonb,
    unit_price numeric,
    total_price numeric,
    delivery_address text,
    buyer_account_id uuid,
    seller_account_id uuid,
    payment_id uuid UNIQUE,
    refund_id uuid UNIQUE,
    payout_id uuid UNIQUE,
    status text NOT NULL DEFAULT 'CREATED',
    reservation_status text,
    cancellation_reason text,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP);

COMMENT ON SCHEMA order_service IS 'Бизнес-данные Order Service; технические таблицы процесса отдельно.';
COMMENT ON TABLE order_service.orders IS 'Одна позиция на заказ; конечные заказы сохраняются бессрочно.';
COMMENT ON COLUMN order_service.orders.id IS 'UUID задаёт клиент. Любая повторная вставка с этим UUID — ошибка.';
COMMENT ON COLUMN order_service.orders.buyer_id IS 'UUID покупателя Keycloak/User Service. Без межбазового FK.';
COMMENT ON COLUMN order_service.orders.product_id IS 'UUID карточки Catalog Service; неизменен. Без межбазового FK.';
COMMENT ON COLUMN order_service.orders.quantity IS 'Исходное количество заказа; не меняется, включая отмену. Частичной доставки нет.';
COMMENT ON COLUMN order_service.orders.seller_id IS 'UUID продавца из каталога; NULL до получения данных.';
COMMENT ON COLUMN order_service.orders.product_name IS 'Снимок названия товара.';
COMMENT ON COLUMN order_service.orders.category_id IS 'UUID категории на момент получения снимка.';
COMMENT ON COLUMN order_service.orders.category_name IS 'Снимок названия категории.';
COMMENT ON COLUMN order_service.orders.product_description IS 'Снимок любого JSON; SQL NULL означает ещё не получено, JSON null допустим.';
COMMENT ON COLUMN order_service.orders.unit_price IS 'Цена единицы в BYN, подтверждённая резервированием; далее неизменна.';
COMMENT ON COLUMN order_service.orders.total_price IS 'Цена всего заказа в BYN; приложение записывает quantity * unit_price. БД не вычисляет.';
COMMENT ON COLUMN order_service.orders.delivery_address IS 'Адрес покупателя при оформлении; не обновляется из профиля позднее.';
COMMENT ON COLUMN order_service.orders.buyer_account_id IS 'Счёт покупателя, фиксируется до первого запроса оплаты.';
COMMENT ON COLUMN order_service.orders.seller_account_id IS 'Актуальный счёт продавца при подготовке выплаты; далее сохраняется для повторов.';
COMMENT ON COLUMN order_service.orders.payment_id IS 'UUID единственной оплаты; генерируется и сохраняется до первого вызова Payment Service.';
COMMENT ON COLUMN order_service.orders.refund_id IS 'UUID единственного полного возврата по исходному платежу; сохраняется до вызова.';
COMMENT ON COLUMN order_service.orders.payout_id IS 'UUID единственной выплаты продавцу; сохраняется до вызова.';
COMMENT ON COLUMN order_service.orders.status IS 'Текущий бизнес-статус заказа; допустимые значения — CHECK, переходы обеспечивает приложение.';
COMMENT ON COLUMN order_service.orders.reservation_status IS 'Последний подтверждённый Catalog Service статус; NULL — ещё не подтверждён, не доказательство отсутствия.';
COMMENT ON COLUMN order_service.orders.cancellation_reason IS 'Первый инициатор отмены BUYER/SELLER/SYSTEM; NULL до принятия отмены. Не подробная ошибка.';
COMMENT ON COLUMN order_service.orders.created_at IS 'Время создания; приложение сохраняет при обновлениях.';
COMMENT ON COLUMN order_service.orders.updated_at IS 'Время последнего фактического изменения; обновляет приложение.';
COMMIT;
