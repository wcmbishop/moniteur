INSERT INTO moniteur_infraction_types VALUES (1,'Stale datasource',0,'False','SELECT
    -- object info
    ds.id AS object_id,
    ds.luid,
    ds.name AS object_name,
    ''Datasource'' AS object_type,
    -- user info
    ds.owner_id AS user_id,
    su.name AS user_name,
    su.email AS user_email,
    su.friendly_name AS user_friendly_name,
    -- infraction info
    ds.extracts_refreshed_at AS last_extract_refresh,
    DATE_PART(''days'', timezone(''UTC'', NOW()) - ds.extracts_refreshed_at) AS infraction_value,
    timezone(''UTC'', CURRENT_TIMESTAMP) AS date_added,
    timezone(''UTC'', CURRENT_TIMESTAMP) AS review_by
FROM public.datasources ds
JOIN public._system_users su ON su.id = ds.owner_id
WHERE ds.data_engine_extracts = True
    AND ds.first_published_at < timezone(''UTC'', NOW()) - INTERVAL ''30 days''
    AND ds.extracts_refreshed_at < timezone(''UTC'', NOW()) - INTERVAL ''30 days''
    AND su.email IS NOT NULL
    -- ?? query ds.extracts_incremented_at as well ??
LIMIT 5','Template','t','False',1,7,'{{user_name}},
<br><br>
{{greeting}}! We have some news. It looks like one or more of your Tableau datasources have not been accessed in over 30 days - FYI! You can find more detail below. If a connection is no longer needed/used, consider removing it from the server (to keep the server running fast and to avoid confusion with users). Thanks!
<br><br>
To learn more about the Tableau monitoring project, <a href="https://confluence.teslamotors.com/display/DATA/Tableau+Server+monitoring">click here</a>.
<br><br>

<ul>
{% for infraction in infractions %}
<li><b>{{ infraction.object_name }}</b></li>
<ul><li>Last accessed: {{ infraction.infraction_value}} days ago</li></ul>
{% endfor %}
</ul>

<br><br>
Tableau Warrior Priests (via <i>moniteur</i>)

','{{user_name}},
<br><br>
{{greeting}}! We have some good news. Your datasource {{object_name}} is no longer stale.
<br><br>
Tableau Warrior Priests (via <i>moniteur</i>)','t','A datasource that has not been viewed in more than 30 days.');
INSERT INTO moniteur_infraction_types VALUES (2,'Automated refreshes',0,'False','SELECT bt2.title, bt2.subtitle, extract_date, a.extract_count,
    COALESCE(ds.owner_name,wb.owner_name) AS user_name,
    bt2.job_name
FROM public._background_tasks bt2
LEFT OUTER JOIN _datasources ds ON ds.name = bt2.title
LEFT OUTER JOIN _workbooks wb ON wb.name = bt2.title
RIGHT JOIN
    (
    SELECT bt1.title, DATE(bt1.started_at) AS extract_date, COUNT(bt1.title) AS extract_count
    FROM public._background_tasks bt1
    GROUP BY bt1.title, extract_date
    ) AS a
ON a.title = bt2.title
WHERE a.extract_date > DATE(NOW()) - INTERVAL ''14 days'' AND (bt2.job_name = ''Refresh Extracts'' OR bt2.job_name = ''Increment Extracts'') AND a.extract_count > 300
LIMIT 500','Archive warning template','Fixed template','False',1,7,'Template','Template','Template','When an object has more than 300 extract refreshes per day from the same user (automated extract refresh abuse).');
INSERT INTO moniteur_infraction_types VALUES (3,'Stale workbook',0,'False','SELECT
    -- object info
    wb.id AS object_id,
    wb.luid AS luid,
    wb.name AS object_name,
    ''Workbook'' AS object_type,
    -- user info
    su.id as user_id,
    su.name AS user_name,
    su.friendly_name AS user_friendly_name,
    su.email AS user_email,
    -- infraction info
    wv.last_view_time,
    DATE_PART(''days'', DATE(NOW()) - wv.last_view_time) AS infraction_value,
    timezone(''UTC'', CURRENT_TIMESTAMP) AS date_added,
    timezone(''UTC'', CURRENT_TIMESTAMP) AS review_by
FROM workbooks AS wb
JOIN public._workbooks AS _wb ON _wb.id = wb.id
LEFT JOIN (
    -- aggregate last view time for each workbook
    SELECT views_workbook_id, MAX(timezone(''UTC'', last_view_time)) as last_view_time
    FROM public._views_stats
    GROUP BY views_workbook_id
     ) wv ON wv.views_workbook_id = wb.id
JOIN public._system_users su ON su.id = wb.owner_id
WHERE wb.created_at < timezone(''UTC'', NOW() - INTERVAL ''30 days'')
    AND (wv.last_view_time IS NULL OR wv.last_view_time < DATE(NOW()) - INTERVAL ''30 days'')
    AND su.email IS NOT NULL
LIMIT 5','{{user_friendly_name}},
<br><br>
{{greeting}}! Your workbook, <b>{{object_name}}</b>, has not been accessed for {{infraction_value}} days. If the workbook is no longer needed/used, please consider removing it from the server (to keep the server running fast and to avoid confusion with users).
<br><br>
If the workbook remains unused by {{archive_date}}, it will be automatically archived.
<br><br>
Tableau Warrior Priests (via <i>moniteur</i>)','NULL','True',3,3,'{{user_name}},
<br><br>
{{greeting}}! We have some news. It looks like one or more of your Tableau datasources have not been accessed in over 30 days - FYI! You can find more detail below. If a connection is no longer needed/used, consider removing it from the server (to keep the server running fast and to avoid confusion with users). Thanks!
<br><br>
To learn more about the Tableau monitoring project, <a href="https://confluence.teslamotors.com/display/DATA/Tableau+Server+monitoring">click here</a>.
<br><br>

<ul>
{% for infraction in infractions %}
<li><b>{{ infraction.object_name }}</b></li>
<ul><li>Last accessed: {{ infraction.infraction_value}} days ago</li></ul>
{% endfor %}
</ul>

<br><br>
Tableau Warrior Priests (via <i>moniteur</i>)','{{user_friendly_name}},
<br><br>
{{greeting}}! We have some good news. Your workbook {{object_name}} is no longer stale.
<br><br>
Tableau Warrior Priests (via <i>moniteur</i>)','{{user_friendly_name}},
<br><br>
{{greeting}}! Your workbook, <b>{{object_name}}</b>, is being archived! You''ll never see it again! We do this at random!
<br><br>
Tableau Warrior Priests (via <i>moniteur</i>)','A workbook that has not been viewed in more than 30 days.');
INSERT INTO moniteur_infraction_types VALUES (4,'Slow loading workbook',0,'False','SELECT
     -- object info
     w.id AS object_id,
     w.luid,
     w.name AS object_name,
     ''Workbook'' AS object_type,
     -- p.name as project_name, -- needed?
     -- user info
     su.id AS user_id,
     su.name AS user_name,
     su.email AS user_email,
     su.friendly_name AS user_friendly_name,
     -- infraction info
     c.show_count,
     c.avg_show_time,
     c.load_count,
     c.avg_load_time,
     c.avg_load_time AS infraction_value,
     -- _v.name as view_name,  -- needed?
     timezone(''UTC'', CURRENT_TIMESTAMP) AS date_added,
     '' '' AS review_by
 FROM (
     SELECT hr.currentsheet,
         hr.site_id,
         COUNT(CASE WHEN hr.action=''show'' THEN 1
             ELSE NULL END) AS show_count,
         AVG(CASE WHEN hr.action=''show'' THEN (hr.completed_at - hr.created_at)
             ELSE NULL END) AS avg_show_time,
         COUNT(CASE WHEN hr.action=''bootstrapSession'' THEN 1
             ELSE NULL END) AS load_count,
         AVG(CASE WHEN hr.action=''bootstrapSession'' THEN (hr.completed_at - hr.created_at)
             ELSE NULL END) AS avg_load_time
     FROM public.http_requests hr
     WHERE hr.created_at > DATE(timezone(''UTC'', NOW())) - INTERVAL ''14 days''
         AND hr.action IN (''show'', ''bootstrapSession'')
         AND hr.currentsheet IS NOT NULL
         AND hr.vizql_session IS NOT NULL
     GROUP BY hr.currentsheet, site_id
     HAVING AVG(CASE WHEN hr.action=''bootstrapSession'' THEN (hr.completed_at - hr.created_at)
              ELSE NULL END) > INTERVAL ''30 sec''
         AND count(CASE WHEN hr.action=''bootstrapSession'' THEN 1
             ELSE NULL END) > 10
      ) c
  JOIN public._views _v ON _v.view_url = c.currentsheet
  JOIN public.workbooks w ON _v.workbook_id = w.id AND c.site_id = w.site_id
  JOIN public._system_users su ON su.id = w.owner_id
 --  LIMIT 50

','Template','NULL','False',1,7,'{{user_name}},

<br><br>

{{greeting}} It looks like one or more of your workbooks has been taking more than 30 seconds to load on average - see further details below. Please work on improving your workbook loading performance to make sure the Tableau server stays fast. Thanks!

<br><br>
To learn more about the Tableau monitoring project, <a href="https://confluence.teslamotors.com/display/DATA/Tableau+Server+monitoring">click here</a>.
<br><br>
<ul>
{% for infraction in infractions %}
<li><b>{{ infraction.object_name }}</b></li>
<ul><li>Average load time: {{infraction.infraction_value}}</li></ul>
{% endfor %}
</ul>

<br><br>

Tableau Warrior Priests (via <i>moniteur</i>)','Template','Template','A workbook that consistently takes longer than 30 seconds to load.');
INSERT INTO moniteur_infraction_types VALUES (5,'Slow per extract time',0,'True','-- IN PROGRESS
SELECT
    -- object info
    c.object_id,
    c.luid,
    c.object_name,
    c.object_type,
    c.priority,
    -- user info
    su.id AS user_id,
    su.name AS user_name,
    su.email AS user_email,
    su.friendly_name AS user_friendly_name,
    -- infraction info
    c.violation_count,
    c.total_count,
    c.avg_extract_time,
    c.violation_count*100/c.total_count AS percent_violations,
    c.violation_count*100/c.total_count AS infraction_value,
    timezone(''UTC'', CURRENT_TIMESTAMP) AS date_added,
    timezone(''UTC'', CURRENT_TIMESTAMP) AS review_by
FROM (
    SELECT COALESCE(wb.id, ds.id) AS object_id,
        COALESCE(_ds.owner_id, _wb.owner_id) AS owner_id,
        bt.title AS object_name,
        bt.subtitle AS object_type,
        bt.priority AS priority,
        COALESCE(ds.luid, wb.luid) AS luid,
        COUNT( CASE WHEN bt.completed_at - bt.started_at > INTERVAL ''60 minutes'' THEN bt.id
                  ELSE NULL
               END ) as violation_count,
        COUNT(bt.id) AS total_count,
        AVG(bt.completed_at - bt.started_at) AS avg_extract_time
    FROM public._background_tasks bt
    LEFT OUTER JOIN datasources ds ON ds.name = bt.title AND bt.subtitle LIKE ''Data%''
    LEFT OUTER JOIN _datasources _ds ON _ds.id = ds.id
    LEFT OUTER JOIN workbooks wb ON wb.name = bt.title AND bt.subtitle = ''Workbook''
    LEFT OUTER JOIN _workbooks _wb ON _wb.id = wb.id
    WHERE bt.finish_code = 0 -- completed extract
        AND bt.started_at > DATE(timezone(''UTC'', NOW())) - INTERVAL ''14 days''
    GROUP BY COALESCE(wb.id, ds.id), COALESCE(_ds.owner_id, _wb.owner_id), bt.title, bt.subtitle, bt.priority,
        COALESCE(ds.luid, wb.luid)
    ) c
JOIN public._system_users su ON su.id = c.owner_id
WHERE c.violation_count*100/c.total_count > 50
    AND c.total_count > 10
LIMIT 5','Template','NULL','False',1,7,'{{user_name}},

<br><br>

{{greeting}} It looks like in the last 14 days, the data extracts for one or more of your Tableau workbooks/datasources have been taking a long time to refresh -- they have run for more than 60 minutes for at least 50% of the runs. See more details below. Please work on decreasing these data extract run times to keep the Tableau server running fast. Thanks!
<br><br>
To learn more about the Tableau monitoring project, <a href="https://confluence.teslamotors.com/display/DATA/Tableau+Server+monitoring">click here</a>.
<br><br>

<ul>
{% for infraction in infractions %}
<li><b>{{ infraction.object_name }}</b> (infraction.object_type)</li>
<ul>
<li>Percent of extracts taking longer than 60 minutes: {{ infraction.infraction_value}}</li>
<li>To view <i>{{infraction.object_name}}</i> in your browser, <a href="{{infraction.object_url}}">click here</a></li>
</ul>
{% endfor %}
</ul>

<br><br>
Tableau Warrior Priests (via <i>moniteur</i>)','Template','Template','This infraction occurs when an object''s extract refreshes are taking longer than 60 minutes to run, more than 50% of the time.');
INSERT INTO moniteur_infraction_types VALUES (6,'Extract refresh failure',0,'False','SELECT
    -- object info
    c.object_id,
    c.luid,
    c.object_name,
    c.object_type,
    c.priority,
    -- user info
    su.id AS user_id,
    su.name AS user_name,
    su.email AS user_email,
    su.friendly_name AS user_friendly_name,
    -- infraction info
    c.failure_count,
    c.total_count,
    c.failure_count*100/c.total_count AS percent_failures,
    c.failure_count*100/c.total_count AS infraction_value,
    timezone(''UTC'', CURRENT_TIMESTAMP) AS date_added,
    '' '' AS review_by
FROM (
    SELECT COALESCE(wb.id, ds.id) AS object_id,
        COALESCE(_ds.owner_id, _wb.owner_id) AS owner_id,
        bt.title AS object_name,
        bt.subtitle AS object_type,
        bt.priority AS priority,
        COALESCE(ds.luid, wb.luid) AS luid,
        COUNT( CASE WHEN bt.finish_code = 1 THEN bt.id
                  ELSE NULL
               END ) as failure_count,
        COUNT(bt.id) AS total_count
    FROM public._background_tasks bt
    LEFT OUTER JOIN datasources ds ON ds.name = bt.title AND bt.subtitle LIKE ''Data%''
    LEFT OUTER JOIN _datasources _ds ON _ds.id = ds.id
    LEFT OUTER JOIN workbooks wb ON wb.name = bt.title AND bt.subtitle = ''Workbook''
    LEFT OUTER JOIN _workbooks _wb ON _wb.id = wb.id
    WHERE bt.started_at > DATE(timezone(''UTC'', NOW())) - INTERVAL ''14 days''
    GROUP BY COALESCE(wb.id, ds.id), COALESCE(_ds.owner_id, _wb.owner_id), bt.title, bt.subtitle, bt.priority,
        COALESCE(ds.luid, wb.luid)
    ) c
JOIN public._system_users su ON su.id = c.owner_id
WHERE c.failure_count*100/c.total_count > 50
    AND c.total_count > 10
-- LIMIT 10','Template','NULL','False',1,7,'{{user_name}},

<br><br>

{{greeting}} We have some news. It looks like one or more of your Tableau workbooks/datasources have been having data extract failures. See below for more details -- each item below has had a data extract fail more than 50% of the time in the last 14 days. Please investigate these failures to see if you can fix the issue. Thanks!
<br><br>
To learn more about the Tableau monitoring project, <a href="https://confluence.teslamotors.com/display/DATA/Tableau+Server+monitoring">click here</a>.
<br><br>

<ul>
{% for infraction in infractions %}
<li><b>{{ infraction.object_name }}</b> (infraction.object_type)</li>
<ul>
<li>Failure rate: {{ infraction.infraction_value}}%</li>
</ul>
{% endfor %}
</ul>

<br><br>
Tableau Warrior Priests (via <i>moniteur</i>)','Template','Template','Object''s extract refreshes are failing more than 50% of the time.');
INSERT INTO moniteur_infraction_types VALUES (7,'Priority 30 abuse',0,'False','-- IN PROGRESS
 SELECT
     -- object info
     c.object_id,
     c.luid,
     c.object_name,
     c.object_type,
     c.priority,
     -- user info
     su.id AS user_id,
     su.name AS user_name,
     su.email AS user_email,
     su.friendly_name AS user_friendly_name,
     -- infraction info
     c.violation_count,
     c.total_count,
     c.avg_extract_time,
     c.violation_count*100/c.total_count AS percent_violations,
     c.violation_count*100/c.total_count AS infraction_value,
     timezone(''UTC'', CURRENT_TIMESTAMP) AS date_added,
     timezone(''UTC'', CURRENT_TIMESTAMP) AS review_by
 FROM (
     SELECT COALESCE(wb.id, ds.id) AS object_id,
         COALESCE(_ds.owner_id, _wb.owner_id) AS owner_id,
         bt.title AS object_name,
         bt.subtitle AS object_type,
         bt.priority AS priority,
         COALESCE(ds.luid, wb.luid) AS luid,
         COUNT( CASE WHEN bt.completed_at - bt.started_at > INTERVAL ''30 seconds'' THEN bt.id
                   ELSE NULL
                END ) as violation_count,
         COUNT(bt.id) AS total_count,
         AVG(bt.completed_at - bt.started_at) AS avg_extract_time
     FROM public._background_tasks bt
     LEFT OUTER JOIN datasources ds ON ds.name = bt.title AND bt.subtitle LIKE ''Data%''
     LEFT OUTER JOIN _datasources _ds ON _ds.id = ds.id
     LEFT OUTER JOIN workbooks wb ON wb.name = bt.title AND bt.subtitle = ''Workbook''
     LEFT OUTER JOIN _workbooks _wb ON _wb.id = wb.id
     WHERE bt.finish_code = 0 -- completed extract
         AND bt.started_at > DATE(timezone(''UTC'', NOW())) - INTERVAL ''14 days''
         AND bt.priority <= 30
     GROUP BY COALESCE(wb.id, ds.id), COALESCE(_ds.owner_id, _wb.owner_id), bt.title, bt.subtitle, bt.priority,
         COALESCE(ds.luid, wb.luid)
     ) c
 JOIN public._system_users su ON su.id = c.owner_id
 WHERE c.violation_count*100/c.total_count > 50
     AND c.total_count > 10
 -- LIMIT 100','Template','NULL','False',1,7,'{{user_name}},

<br><br>

{{greeting}}  It looks like in the last 14 days, the data extracts for one or more of your Tableau workbooks/datasources have refreshed a bit slowly -- they have not met our goal of 30 seconds for priority levels <= 30. See below for more details -- each item has taken longer than 30 seconds to refresh more than 50% of the time. We reserve extract priorities <= 30 for time-sensitive extracts that run in 30 seconds or less (to avoid blocking other extracts). Please work on improving the extract run times or adjust the priority level accordingly (according to <a href="https://confluence.teslamotors.com/display/DATA/Tableau+Best+Practices">guidelines here</a>). Thanks!
<br><br>
To learn more about the Tableau monitoring project, <a href="https://confluence.teslamotors.com/display/DATA/Tableau+Server+monitoring">click here</a>.
<br><br>

<ul>
{% for infraction in infractions %}
<li><b>{{ infraction.object_name }}</b> (infraction.object_type)</li>
<ul>
<li>Percent of extracts taking longer than 30 seconds: {{ infraction.infraction_value}}</li>
</ul>
{% endfor %}
</ul>

<br><br>
Tableau Warrior Priests (via <i>moniteur</i>)
','Template','Template','An object with a priority level of 30 is running extracts for longer than 30 seconds more than 50% of the time.');
INSERT INTO moniteur_infraction_types VALUES (8,'Priority 40 abuse',0,'False','SELECT
     -- object info
     c.object_id,
     c.luid,
     c.object_name,
     c.object_type,
     c.priority,
     -- user info
     su.id AS user_id,
     su.name AS user_name,
     su.email AS user_email,
     su.friendly_name AS user_friendly_name,
     -- infraction info
     c.violation_count,
     c.total_count,
     c.avg_extract_time,
     c.violation_count*100/c.total_count AS percent_violations,
     c.violation_count*100/c.total_count AS infraction_value,
     timezone(''UTC'', CURRENT_TIMESTAMP) AS date_added,
     timezone(''UTC'', CURRENT_TIMESTAMP) AS review_by
 FROM (
     SELECT COALESCE(wb.id, ds.id) AS object_id,
         COALESCE(_ds.owner_id, _wb.owner_id) AS owner_id,
         bt.title AS object_name,
         bt.subtitle AS object_type,
         bt.priority AS priority,
         COALESCE(ds.luid, wb.luid) AS luid,
         COUNT( CASE WHEN bt.completed_at - bt.started_at > INTERVAL ''180 seconds'' THEN bt.id
                   ELSE NULL
                END ) as violation_count,
         COUNT(bt.id) AS total_count,
         AVG(bt.completed_at - bt.started_at) AS avg_extract_time
     FROM public._background_tasks bt
     LEFT OUTER JOIN datasources ds ON ds.name = bt.title AND bt.subtitle LIKE ''Data%''
     LEFT OUTER JOIN _datasources _ds ON _ds.id = ds.id
     LEFT OUTER JOIN workbooks wb ON wb.name = bt.title AND bt.subtitle = ''Workbook''
     LEFT OUTER JOIN _workbooks _wb ON _wb.id = wb.id
     WHERE bt.finish_code = 0 -- completed extract
         AND bt.started_at > DATE(timezone(''UTC'', NOW())) - INTERVAL ''14 days''
         AND bt.priority > 30 AND bt.priority <= 40
     GROUP BY COALESCE(wb.id, ds.id), COALESCE(_ds.owner_id, _wb.owner_id), bt.title, bt.subtitle, bt.priority,
         COALESCE(ds.luid, wb.luid)
     ) c
 JOIN public._system_users su ON su.id = c.owner_id
 WHERE c.violation_count*100/c.total_count > 50
     AND c.total_count > 10
 -- LIMIT 100','Tempate','NULL','False',1,7,'{{user_name}},

<br><br>

{{greeting}} It looks like in the last 14 days, the data extracts for one or more of your Tableau workbooks/datasources have refreshed a bit slowly -- they have not met our goal of 180 seconds for priority levels <= 40. See below for more details -- each item has taken longer than 180 seconds to refresh more than 50% of the time. We reserve extract priority 40 for extracts that run in 180 seconds or less (to avoid blocking faster extracts). Please work on improving the extract run times or adjust the priority level accordingly (according to <a href="https://confluence.teslamotors.com/display/DATA/Tableau+Best+Practices">guidelines here</a>). Thanks!
<br><br>
To learn more about the Tableau monitoring project, <a href="https://confluence.teslamotors.com/display/DATA/Tableau+Server+monitoring">click here</a>.
<br><br>

<ul>
{% for infraction in infractions %}
<li><b>{{ infraction.object_name }}</b> (infraction.object_type)</li>
<ul>
<li>Percent of extracts taking longer than 180 seconds: {{ infraction.infraction_value}}</li>
</ul>
{% endfor %}
</ul>

<br><br>
Tableau Warrior Priests (via <i>moniteur</i>)','Tempate','Tempate','An object with a priority level of 40 is running extracts for longer than 180 seconds more than 50% of the time.');
INSERT INTO moniteur_infraction_types VALUES (9,'Priority 50 abuse',0,'False','SELECT
     -- object info
     c.object_id,
     c.luid,
     c.object_name,
     c.object_type,
     c.priority,
     -- user info
     su.id AS user_id,
     su.name AS user_name,
     su.email AS user_email,
     su.friendly_name AS user_friendly_name,
     -- infraction info
     c.violation_count,
     c.total_count,
     c.avg_extract_time,
     c.violation_count*100/c.total_count AS percent_violations,
     c.violation_count*100/c.total_count AS infraction_value,
     timezone(''UTC'', CURRENT_TIMESTAMP) AS date_added,
     timezone(''UTC'', CURRENT_TIMESTAMP) AS review_by
 FROM (
     SELECT COALESCE(wb.id, ds.id) AS object_id,
         COALESCE(_ds.owner_id, _wb.owner_id) AS owner_id,
         bt.title AS object_name,
         bt.subtitle AS object_type,
         bt.priority AS priority,
         COALESCE(ds.luid, wb.luid) AS luid,
         COUNT( CASE WHEN bt.completed_at - bt.started_at > INTERVAL ''10 minutes'' THEN bt.id
                   ELSE NULL
                END ) as violation_count,
         COUNT(bt.id) AS total_count,
         AVG(bt.completed_at - bt.started_at) AS avg_extract_time
     FROM public._background_tasks bt
     LEFT OUTER JOIN datasources ds ON ds.name = bt.title AND bt.subtitle LIKE ''Data%''
     LEFT OUTER JOIN _datasources _ds ON _ds.id = ds.id
     LEFT OUTER JOIN workbooks wb ON wb.name = bt.title AND bt.subtitle = ''Workbook''
     LEFT OUTER JOIN _workbooks _wb ON _wb.id = wb.id
     WHERE bt.finish_code = 0 -- completed extract
         AND bt.started_at > DATE(timezone(''UTC'', NOW())) - INTERVAL ''14 days''
         AND bt.priority > 40 AND bt.priority <= 50
     GROUP BY COALESCE(wb.id, ds.id), COALESCE(_ds.owner_id, _wb.owner_id), bt.title, bt.subtitle, bt.priority,
         COALESCE(ds.luid, wb.luid)
     ) c
 JOIN public._system_users su ON su.id = c.owner_id
 WHERE c.violation_count*100/c.total_count > 50
     AND c.total_count > 10
 -- LIMIT 100','Template','NULL','False',1,7,'{{user_name}},

<br><br>

{{greeting}}  Hello! It looks like in the last 14 days, the data extracts for one or more of your Tableau workbooks/datasources have refreshed a bit slowly -- they have not met our goal of 10 minutes for priority levels <= 50. See below for more details -- each item has taken longer than 10 minutes to refresh more than 50% of the time. We reserve extract priority 50 for extracts that run in 10 minutes or less (to avoid blocking faster extracts). Please work on improving the extract run times or adjust the priority level accordingly (according to <a href="https://confluence.teslamotors.com/display/DATA/Tableau+Best+Practices">guidelines here</a>). Thanks!
<br><br>
To learn more about the Tableau monitoring project, <a href="https://confluence.teslamotors.com/display/DATA/Tableau+Server+monitoring">click here</a>.
<br><br>

<ul>
{% for infraction in infractions %}
<li><b>{{ infraction.object_name }}</b> (infraction.object_type)</li>
<ul>
<li>Percent of extracts taking longer than 10 minutes: {{ infraction.infraction_value}}</li>
</ul>
{% endfor %}
</ul>

<br><br>
Tableau Warrior Priests (via <i>moniteur</i>)
','Template','Template','An object with a priority level of 50 is running extracts for longer than 10 minutes more than 50% of the time.');
INSERT INTO moniteur_infraction_types VALUES (10,'Priority 60 abuse',0,'False','SELECT
     -- object info
     c.object_id,
     c.luid,
     c.object_name,
     c.object_type,
     c.priority,
     -- user info
     su.id AS user_id,
     su.name AS user_name,
     su.email AS user_email,
     su.friendly_name AS user_friendly_name,
     -- infraction info
     c.violation_count,
     c.total_count,
     c.avg_extract_time,
     c.violation_count*100/c.total_count AS percent_violations,
     c.violation_count*100/c.total_count AS infraction_value,
     timezone(''UTC'', CURRENT_TIMESTAMP) AS date_added,
     timezone(''UTC'', CURRENT_TIMESTAMP) AS review_by
 FROM (
     SELECT COALESCE(wb.id, ds.id) AS object_id,
         COALESCE(_ds.owner_id, _wb.owner_id) AS owner_id,
         bt.title AS object_name,
         bt.subtitle AS object_type,
         bt.priority AS priority,
         COALESCE(ds.luid, wb.luid) AS luid,
         COUNT( CASE WHEN bt.completed_at - bt.started_at > INTERVAL ''30 minutes'' THEN bt.id
                   ELSE NULL
                END ) as violation_count,
         COUNT(bt.id) AS total_count,
         AVG(bt.completed_at - bt.started_at) AS avg_extract_time
     FROM public._background_tasks bt
     LEFT OUTER JOIN datasources ds ON ds.name = bt.title AND bt.subtitle LIKE ''Data%''
     LEFT OUTER JOIN _datasources _ds ON _ds.id = ds.id
     LEFT OUTER JOIN workbooks wb ON wb.name = bt.title AND bt.subtitle = ''Workbook''
     LEFT OUTER JOIN _workbooks _wb ON _wb.id = wb.id
     WHERE bt.finish_code = 0 -- completed extract
         AND bt.started_at > DATE(timezone(''UTC'', NOW())) - INTERVAL ''14 days''
         AND bt.priority > 50
     GROUP BY COALESCE(wb.id, ds.id), COALESCE(_ds.owner_id, _wb.owner_id), bt.title, bt.subtitle, bt.priority,
         COALESCE(ds.luid, wb.luid)
     ) c
 JOIN public._system_users su ON su.id = c.owner_id
 WHERE c.violation_count*100/c.total_count > 50
     AND c.total_count > 10
 -- LIMIT 100','Template','NULL','False',1,7,'{{user_name}},

<br><br>

{{greeting}} It looks like in the last 14 days, the data extracts for one or more of your Tableau workbooks/datasources have been refreshing really slowly! They have taken more than 30 minutes to complete at least 50% of the time. Please work on improving the extract run times to keep the Tableau server running fast. Thanks!
<br><br>
To learn more about the Tableau monitoring project, <a href="https://confluence.teslamotors.com/display/DATA/Tableau+Server+monitoring">click here</a>.
<br><br>

<ul>
{% for infraction in infractions %}
<li><b>{{ infraction.object_name }}</b> (infraction.object_type)</li>
<ul>
<li>Percent of extracts taking longer than 30 minutes: {{ infraction.infraction_value}}</li>
</ul>
{% endfor %}
</ul>

<br><br>
Tableau Warrior Priests (via <i>moniteur</i>)','Template','Template','An object with a priority level of 60 is running extracts for longer than 30 minutes more than 50% of the time.');
INSERT INTO moniteur_infraction_types VALUES (11,'Slow daily extract time',0,'False','SELECT
     -- object info
     title as object_name,
     subtitle AS object_type,
     COALESCE(ds.id, wb.id) AS object_id,
     COALESCE(ds.luid, wb.luid) AS luid,
     -- user info
     su.name AS user_name,
     su.id AS user_id,
     su.friendly_name AS user_friendly_name,
     su.email AS user_email,
     -- infraction info
     AVG(time_per_day) AS avg_time_per_day,
     DATE_PART(''hour'', AVG(time_per_day))*60 + DATE_PART(''minute'', AVG(time_per_day)) AS infraction_value,
     timezone(''UTC'', CURRENT_TIMESTAMP) AS date_added,
     '' '' AS review_by
  FROM (
     -- query daily total extract time per object
     SELECT title, subtitle, DATE(timezone(''UTC'', started_at)) as extract_date,  SUM(completed_at - started_at) AS time_per_day
     FROM _background_tasks
     WHERE started_at > DATE(timezone(''UTC'', NOW()) - INTERVAL ''14 days'')
     GROUP BY title, subtitle, extract_date
     ) AS time_summary
 LEFT OUTER JOIN datasources ds ON ds.name = title AND subtitle LIKE ''Data%''
 LEFT OUTER JOIN _datasources _ds ON _ds.id = ds.id
 LEFT OUTER JOIN workbooks wb ON wb.name = title AND subtitle = ''Workbook''
 LEFT OUTER JOIN _workbooks _wb ON _wb.id = wb.id
 JOIN _system_users su ON su.id = COALESCE(_ds.owner_id, _wb.owner_id)
 GROUP BY title, subtitle, COALESCE(ds.luid, wb.luid), user_name, su.email, user_id, COALESCE(ds.id, wb.id), su.friendly_name, review_by
 HAVING AVG(time_per_day) > INTERVAL ''4 hours''
 -- LIMIT 10','Template','NULL','False',1,7,'{{user_name}},

<br><br>

{{greeting}} It looks like one or more of your Tableau workbooks/datasources have been spending a lot of time refreshing data extracts. See below for more details -- each item has had an extract running for more than 4 hours/day on average over the last 14 days. Please work on descreasing this cumulative extract refresh time to keep the Tableau server running fast. Thanks!
<br><br>
To learn more about the Tableau monitoring project, <a href="https://confluence.teslamotors.com/display/DATA/Tableau+Server+monitoring">click here</a>.
<br><br>

<ul>
{% for infraction in infractions %}
<li><b>{{ infraction.object_name }}</b> (infraction.object_type)</li>
<ul>
<li>Average minutes per day: {{ infraction.infraction_value}}</li>
</ul>
{% endfor %}
</ul>

<br><br>
Tableau Warrior Priests (via <i>moniteur</i>)','Template','Template','An object''s extracts run for longer than 4 hours a day, more than 50% of the time.');
