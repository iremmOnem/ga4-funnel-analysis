-- =========================================================
-- GA4 Funnel Analysis Project
-- Session + Event level funnel dataset
-- Built using BigQuery SQL
-- =========================================================

-- =========================================================
-- GA4 FUNNEL ANALYSIS QUERY
-- Bu sorgu e-ticaret funnel (dönüşüm hunisi) analizi yapmak için yazılmıştır.
-- Amaç: Session (oturum) + Event (kullanıcı aksiyonları) verisini birleştirmek
-- =========================================================

-- =========================================================
-- 1. CTE: sessions_info
-- Bu bölüm SADECE session_start event'lerinden çalışır
-- Yani her satır = 1 oturum başlangıcı
-- =========================================================

WITH sessions_info AS (

  SELECT
    user_pseudo_id,
    -- Kullanıcıyı anonim olarak temsil eden ID
    -- Aynı kullanıcı birden fazla session açabilir

    (SELECT value.int_value 
     FROM UNNEST(event_params) 
     WHERE key = 'ga_session_id') AS session_id,
    -- GA4 içinde her session’a ait ID
    -- event_params içinden çekiyoruz (nested yapı olduğu için UNNEST kullanılır)

    CONCAT(
      user_pseudo_id,
      '-',
      CAST((SELECT value.int_value 
            FROM UNNEST(event_params) 
            WHERE key = 'ga_session_id') AS STRING)
    ) AS user_session_id,
    -- user + session birleşimi
    -- çünkü aynı user birden fazla session açabilir
    -- bu alan join işlemi için kullanılacak

    TIMESTAMP_MICROS(event_timestamp) AS session_start_time,
    -- event zamanı mikro saniye formatında gelir
    -- bunu okunabilir datetime formatına çeviriyoruz

    device.category AS device_category,
    -- cihaz tipi: mobile / desktop / tablet

    device.language AS device_language,
    -- kullanıcının cihaz dili: tr-tr, en-us gibi

    device.operating_system AS operating_system,
    -- işletim sistemi: iOS, Android, Windows

    traffic_source.source AS source,
    -- trafik kaynağı: Google, Direct, Facebook

    traffic_source.medium AS medium,
    -- trafik türü: organic, cpc, referral

    traffic_source.name AS campaign
    -- kampanya adı (varsa)

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

  WHERE event_name = 'session_start'
  -- SADECE oturum başlangıçlarını alıyoruz
),

-- =========================================================
-- 2. CTE: events
-- Bu bölüm funnel’daki kullanıcı aksiyonlarını içerir
-- Yani kullanıcı site içinde ne yaptı?
-- =========================================================

events AS (

  SELECT
    user_pseudo_id,
    -- aynı kullanıcı ID

    (SELECT value.int_value 
     FROM UNNEST(event_params) 
     WHERE key = 'ga_session_id') AS session_id,
    -- yine session id alıyoruz (join için gerekli)

    CONCAT(
      user_pseudo_id,
      '-',
      CAST((SELECT value.int_value 
            FROM UNNEST(event_params) 
            WHERE key = 'ga_session_id') AS STRING)
    ) AS user_session_id,
    -- sessions_info ile eşleşebilmek için aynı ID üretimi

    event_name,
    -- kullanıcının yaptığı aksiyon:
    -- view_item, add_to_cart, purchase vs.

    TIMESTAMP_MICROS(event_timestamp) AS event_time
    -- aksiyonun gerçekleştiği zaman

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

  WHERE event_name IN (
    'session_start',       -- siteye giriş
    'view_item',           -- ürün görüntüleme
    'add_to_cart',         -- sepete ekleme
    'begin_checkout',      -- checkout başlatma
    'add_shipping_info',   -- kargo bilgisi girme
    'add_payment_info',    -- ödeme bilgisi girme
    'purchase'             -- satın alma
  )
)

-- =========================================================
-- 3. FINAL SELECT (JOIN)
-- Burada session bilgileri ile event bilgilerini birleştiriyoruz
-- =========================================================

SELECT
  s.user_pseudo_id,
  -- kullanıcı

  s.user_session_id,
  -- session bazlı analiz için en önemli alan

  s.session_start_time,
  -- session başlangıcı

  e.event_name,
  -- kullanıcının yaptığı aksiyon

  e.event_time,
  -- aksiyon zamanı

  s.device_category,
  s.device_language,
  s.operating_system,
  -- cihaz bilgileri

  s.source,
  s.medium,
  s.campaign
  -- trafik bilgileri

FROM sessions_info s

LEFT JOIN events e
ON s.user_session_id = e.user_session_id
-- session bazlı join
-- LEFT JOIN kullanıyoruz çünkü:
-- her session'da event olmayabilir
-- ama session'ı kaybetmek istemiyoruz
