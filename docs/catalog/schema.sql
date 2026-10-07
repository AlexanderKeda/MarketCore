-- CatalogDB: проектная схема, не миграция и не скрипт изменения существующей БД.
-- Выполнять целиком в пустой тестовой PostgreSQL-базе.
BEGIN;
CREATE SCHEMA catalog;

CREATE TABLE catalog.category (
    id uuid PRIMARY KEY,
    name text NOT NULL,
    CONSTRAINT category_name_unique UNIQUE (name),
    CONSTRAINT category_name_not_blank CHECK (btrim(name) <> '')
);

CREATE TABLE catalog.product (
    id uuid PRIMARY KEY,
    seller_id uuid NOT NULL,
    category_id uuid NOT NULL REFERENCES catalog.category(id) ON DELETE RESTRICT,
    name text NOT NULL,
    description jsonb NOT NULL,
    price numeric NOT NULL,
    available_quantity bigint NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT product_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT product_price_valid CHECK
        (price > 0 AND price < 'Infinity'::numeric AND price = trunc(price, 2)),
    CONSTRAINT product_quantity_valid CHECK (available_quantity >= 0),
    CONSTRAINT product_status_valid CHECK (status IN ('ACTIVE', 'HIDDEN')),
    CONSTRAINT product_hidden_empty CHECK (status <> 'HIDDEN' OR available_quantity = 0)
);

CREATE TABLE catalog.reservation (
    order_id uuid PRIMARY KEY,
    product_id uuid NOT NULL REFERENCES catalog.product(id) ON DELETE RESTRICT,
    quantity bigint NOT NULL,
    unit_price numeric NOT NULL,
    status text NOT NULL DEFAULT 'RESERVED',
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT reservation_status_valid CHECK
        (status IN ('RESERVED', 'IN_DELIVERY', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT reservation_quantity_valid CHECK
        ((status = 'CANCELLED' AND quantity = 0)
         OR (status IN ('RESERVED', 'IN_DELIVERY', 'COMPLETED') AND quantity > 0)),
    CONSTRAINT reservation_price_valid CHECK
        (unit_price > 0 AND unit_price < 'Infinity'::numeric
         AND unit_price = trunc(unit_price, 2))
);

-- Точное имя категории уникально; нормализация регистра не вводится.
CREATE INDEX product_category_idx ON catalog.product (category_id);
CREATE INDEX product_public_search_idx ON catalog.product (category_id, name, id)
    WHERE status = 'ACTIVE' AND available_quantity > 0;
CREATE INDEX product_seller_list_idx ON catalog.product (seller_id, status, name, id);
CREATE INDEX reservation_product_idx ON catalog.reservation (product_id);
CREATE INDEX reservation_open_product_idx ON catalog.reservation (product_id)
    WHERE status IN ('RESERVED', 'IN_DELIVERY');

-- Обновляем время только при фактическом изменении записи.
CREATE FUNCTION catalog.touch_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.created_at := OLD.created_at;
    NEW.updated_at := OLD.updated_at;
    IF NEW IS DISTINCT FROM OLD THEN
        NEW.updated_at := clock_timestamp();
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER product_touch_updated_at BEFORE UPDATE ON catalog.product
    FOR EACH ROW EXECUTE FUNCTION catalog.touch_updated_at();
CREATE TRIGGER reservation_touch_updated_at BEFORE UPDATE ON catalog.reservation
    FOR EACH ROW EXECUTE FUNCTION catalog.touch_updated_at();

COMMENT ON SCHEMA catalog IS 'Данные Catalog Service; без прямого доступа к чужим БД.';
COMMENT ON TABLE catalog.category IS 'Плоский справочник; первоначальные значения задаются отдельно.';
COMMENT ON COLUMN catalog.category.id IS 'UUID категории, задаётся приложением или начальными данными.';
COMMENT ON COLUMN catalog.category.name IS 'Уникальное непустое название категории.';
COMMENT ON TABLE catalog.product IS 'Карточка одного продавца; физическое удаление не используется.';
COMMENT ON COLUMN catalog.product.id IS 'UUID карточки, генерируется приложением.';
COMMENT ON COLUMN catalog.product.seller_id IS 'UUID Keycloak = UUID профиля User Service; внешний FK отсутствует.';
COMMENT ON COLUMN catalog.product.category_id IS 'Единственная категория товара.';
COMMENT ON COLUMN catalog.product.name IS 'Название; совпадения между карточками разрешены.';
COMMENT ON COLUMN catalog.product.description IS 'Любой JSON, включая JSON null; SQL NULL запрещён.';
COMMENT ON COLUMN catalog.product.price IS 'Текущая цена единицы в BYN; положительная, шаг 0.01.';
COMMENT ON COLUMN catalog.product.available_quantity IS 'Доступное для новых заказов количество; не физическое наличие.';
COMMENT ON COLUMN catalog.product.status IS 'ACTIVE — активная; HIDDEN — скрытая.';
COMMENT ON COLUMN catalog.product.created_at IS 'Время создания карточки.';
COMMENT ON COLUMN catalog.product.updated_at IS 'Время последнего фактического изменения карточки.';
COMMENT ON TABLE catalog.reservation IS 'Один резерв на заказ; конечные записи сохраняются бессрочно.';
COMMENT ON COLUMN catalog.reservation.order_id IS 'UUID заказа; PK одновременно обеспечивает UNIQUE и NOT NULL; FK в OrderDB отсутствует.';
COMMENT ON COLUMN catalog.reservation.product_id IS 'Карточка зарезервированного товара.';
COMMENT ON COLUMN catalog.reservation.quantity IS 'Количество сохраняется при доставке/завершении; при отмене обнуляется после возврата.';
COMMENT ON COLUMN catalog.reservation.unit_price IS 'Цена единицы в BYN на момент резервирования; далее не меняется.';
COMMENT ON COLUMN catalog.reservation.status IS 'RESERVED — в резерве; IN_DELIVERY — в доставке; COMPLETED — завершён; CANCELLED — отменён.';
COMMENT ON COLUMN catalog.reservation.created_at IS 'Дата и время резервирования.';
COMMENT ON COLUMN catalog.reservation.updated_at IS 'Время последнего фактического изменения резерва.';
COMMIT;
