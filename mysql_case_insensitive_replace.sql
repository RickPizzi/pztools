DROP FUNCTION IF EXISTS replace_ci;
SET NAMES UTF8;
DELIMITER $$

CREATE FUNCTION `replace_ci` ( str TEXT CHARSET utf8, needle CHAR(255) CHARSET utf8, str_rep CHAR(255) CHARSET utf8)
RETURNS TEXT CHARSET utf8
DETERMINISTIC
BEGIN
DECLARE return_str TEXT CHARSET utf8 DEFAULT '';
DECLARE lower_str TEXT CHARSET utf8;
DECLARE lower_needle TEXT CHARSET utf8;
DECLARE pos INT DEFAULT 1;
DECLARE old_pos INT DEFAULT 1;
IF needle = '' THEN
	RETURN str;
END IF;

SELECT lower(str) INTO lower_str;
SELECT lower(needle) INTO lower_needle;
SELECT locate(lower_needle, lower_str, pos) INTO pos;
WHILE pos > 0
DO
	SELECT concat(return_str, substr(str, old_pos, pos-old_pos), str_rep) INTO return_str;
	SELECT pos + char_length(needle) INTO pos;
	SELECT pos INTO old_pos;
	SELECT locate(lower_needle, lower_str, pos) INTO pos;
END WHILE;
SELECT concat(return_str, substr(str, old_pos, char_length(str))) INTO return_str;
RETURN return_str;
END
$$

DELIMITER ;

