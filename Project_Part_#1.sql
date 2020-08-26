-- 1. Аналитическая таблица с частотами по дням.
SELECT date, count(event) AS num_events,
       countIf(event = 'view') AS num_views,
       countIf(event = 'click') AS num_clicks,
       uniqExact(ad_id) AS num_ads,
       uniqExact(campaign_union_id) AS num_camp
FROM ads_data
GROUP BY date
ORDER BY date;

-- 2. Почему скачок 2019-04-05? Пусть t - период аномалии.
-- Выкидываем лишние даты. Ориентируемся на периоды t-1, t и t+1.

-- Гипотеза 1. Возможно, платформа? Скорее нет.
-- Просмотры выросли примерно в 2 раза по сравнению с t-1.
-- Соответственно, подтянулись и клики. CTR, % увеличился.
-- Но это все более-менее равномерно по каналам.
SELECT date, platform, count(event) AS num_events,
       countIf(event = 'view') AS num_views,
       countIf(event = 'click') AS num_clicks,
       round(num_clicks / num_views * 100, 2) AS ctr,
       uniqExact(ad_id) AS num_ads,
       uniqExact(campaign_union_id) AS num_camp,
       round(num_events / num_ads, 1) AS events_per_ad
FROM ads_data
WHERE toDate(date) >= toDate('2019-04-04')
GROUP BY date, platform
ORDER BY platform, date;

-- Гипотеза 2. Тогда мб влияние типа объявления (ad_cost_type)?
-- Так и есть. В 2 раза выросло число CPM-объявлений.
-- Естественно, показы выросли, как и клики.
-- Увеличилось давление (N event'ов) по каждому из рекламных объявлений.
-- Это вызвало резкий рост ctr в период t.
-- В периоде t+1 эффект от количества объявлений в прошлом периоде сохранился.
-- CTR не упал,а даже вырос при сокращении event'ов в этом периоде.
-- В целом, видно, что CPM стали эффективнее CPC.
-- Вывод: масштабные кампании стоит проводить с некой цикличностью,
-- чтобы играть на сохранении эффекта в следующих периодах, экономя издержки.
SELECT date, ad_cost_type, count(event) AS num_events,
       countIf(event = 'view') AS num_views,
       countIf(event = 'click') AS num_clicks,
       round(num_clicks / num_views * 100, 2) AS ctr,
       uniqExact(ad_id) AS num_ads,
       uniqExact(campaign_union_id) AS num_camp,
       round(num_events / num_ads, 1) AS events_per_ad
FROM ads_data
WHERE toDate(date) >= toDate('2019-04-04')
GROUP BY date, ad_cost_type
ORDER BY ad_cost_type, date;

-- :(
-- Ну ладно. Тогда смотрим топ-5 объявлений по числу событий за день для t-1, t и t+1.
SELECT *
FROM (
SELECT date, ad_id, count(event) AS num_events,
       countIf(event = 'view') AS num_views,
       countIf(event = 'click') AS num_clicks,
       round(num_clicks / num_views * 100, 2) AS ctr
FROM ads_data
WHERE toDate(date) >= toDate('2019-04-04')
GROUP BY date, ad_id
ORDER BY num_events desc
LIMIT 5 BY date)
ORDER BY date, num_events desc;

-- В скачке виновато объявление с id 112583.
-- История объявления начинается сразу в пиковый период.
-- Видимо, рекламная кампания наиболее интенсивно стартует в 1-ый день.
SELECT date, ad_id, count(event) AS num_events,
       countIf(event = 'view') AS num_views,
       countIf(event = 'click') AS num_clicks,
       round(num_clicks / num_views * 100, 2) AS ctr
FROM ads_data
WHERE ad_id = 112583
GROUP BY date, ad_id
ORDER BY date;

-- 3. Топ-10 ad по CTR, %
-- Есть баги с 0 просмотров и > 0 кликов
SELECT ad_id,
       countIf(event = 'view') AS num_views,
       countIf(event = 'click') AS num_clicks,
       round(num_clicks / num_views * 100, 2) AS ctr
FROM ads_data
GROUP BY ad_id
HAVING num_views > 0 -- фильтруем ctr = ∞
ORDER BY ctr desc
LIMIT 10;

-- Средняя и медиана довольно сильно отличаются.
-- CTR средний составляет 1.58%, медианный - 0.29%.
SELECT round(avg(num_clicks / num_views * 100), 2) AS avg_ctr,
       round(median(num_clicks / num_views * 100), 2) AS med_ctr
FROM (
     SELECT ad_id,
            countIf(event = 'view') AS num_views,
            countIf(event = 'click') AS num_clicks
     FROM ads_data
     GROUP BY ad_id
     HAVING num_views > 0); -- фильтруем ctr = ∞

-- 4. Заметили баги с показами. Стараемся исследовать
-- Нашли всего 9 объявлений, у которых число кликов > числа показов
SELECT ad_id,
       countIf(event = 'view') AS num_views,
       countIf(event = 'click') AS num_clicks,
       countIf(has_video = 1) AS num_videos
FROM ads_data
GROUP BY ad_id, has_video
HAVING num_clicks > num_views
ORDER BY ad_id;

-- Наблюдается для всех платформ
SELECT *
FROM ads_data
WHERE ad_id = 26204;

--
SELECT ad_id, groupArray(toDate(time)) as all_dates_from_timestamp,
       countIf(event = 'view') AS num_views,
       countIf(event = 'click') AS num_clicks
FROM ads_data
GROUP BY ad_id, has_video
HAVING num_clicks > num_views
ORDER BY ad_id;

-- 5. CTR с видео и без.
-- Во-первых, все
-- Конечно, есть различия, когда CTR срывается в ∞.
SELECT has_video,
       round(avg(num_clicks / num_views * 100), 2) AS avg_ctr,
       round(median(num_clicks / num_views * 100), 2) AS median_ctr
FROM (
    SELECT ad_id, has_video,
       countIf(event = 'view') AS num_views,
       countIf(event = 'click') AS num_clicks
    FROM ads_data
    GROUP BY ad_id, has_video
    HAVING num_views >= num_clicks
    ORDER BY has_video desc)
GROUP BY has_video;


-- 95-ый перцентиль по всем объявлениям за 2019-04-04
SELECT round(quantileExact(0.95)(num_clicks / num_views * 100), 2) AS perc_95_ctr
FROM (
    SELECT ad_id,
       countIf(event = 'view') AS num_views,
       countIf(event = 'click') AS num_clicks
    FROM ads_data
    WHERE date = toDate('2019-04-04')
    GROUP BY ad_id);

-- 6. Расчет заработка (выручки). CPM - за 1000 показов
-- Ожидаемо, больше всего заработали в дату, где был рекламный всплеск CPM, - 2019-04-05
-- Меньше всего заработали 2019-04-01 - в 14.4 раза меньше, чем 2019-04-05

SELECT date, round(sum(multiIf((event = 'click' and ad_cost_type = 'CPC'),
           ad_cost, (event = 'view' and ad_cost_type = 'CPM'),
           ad_cost/1000, 0)), 2) as total_revenue
FROM ads_data
GROUP BY date;

-- 7. Самая популярная платформа по событиям в целом - android. Следом идет ios, затем web.
-- Около 50% просмотров приходятся на android, около 30% - на ios, остальные 20% - на web.
WITH (SELECT countIf(event='view')
      FROM ads_data) as sum_views

SELECT platform, num_events, num_views,
       round(num_views / sum_views * 100, 2) as views_perc
FROM (
SELECT platform,
       count(event) AS num_events,
       countIf(event='view') as num_views
FROM ads_data
GROUP BY platform);

-- 8. Фейл: сначала клик, потом показ с окном в 48 часов
SELECT ad_id, platform,
       windowFunnel(172800)(time, event = 'click', event='view') as num_fails
FROM ads_data
GROUP BY ad_id, platform
HAVING num_fails > 0
ORDER BY ad_id;

-- Сколько % объявлений не имеют такой баг
WITH (SELECT uniqExact(ad_id) FROM ads_data) as num_ads
SELECT round(count(ad_id) / num_ads * 100, 2) as perc_no_fail
FROM (
SELECT ad_id,
       windowFunnel(172800)(time, event = 'click', event='view') as num_fails
FROM ads_data
GROUP BY ad_id
HAVING num_fails = 0
ORDER BY num_fails desc);

SELECT *
FROM ads_data