                       --Fiziki və Hüquqi şəxslərlərin limit summaları və transfer 
                                 -- məbləğləri üzrə layihə işi
                                 

--1. Excelin “Tables” sheetindəki bütün table-ları yaratmaq və aralarında əlaqəni düzgün şəkildə
                            --təyin etmək.                                 
                            
CREATE TABLE customers (CUSTOMER_NO NUMBER,
                        CUSTOMER_TYPE VARCHAR2(1),
                        FULL_NAME VARCHAR2(300),
                        ADDRESS_LINE1 VARCHAR2(300),
                        ADDRESS_LINE2 VARCHAR2(300),
                        ADDRESS_LINE3 VARCHAR2(300),
                        ADDRESS_LINE4 VARCHAR2(300),  --cedvel yaradildi
                        COUNTRY VARCHAR2(300),
                        LANGUAGE VARCHAR2(300),
                        BRANCH_ID NUMBER,
                        PASSWORD_NO VARCHAR2(300),
                        LIMIT NUMBER,
                        LIMIT_CCY NUMBER);
                        
ALTER TABLE customers MODIFY CUSTOMER_NO PRIMARY KEY;  -- primary key qoyuldu                
ALTER TABLE customers MODIFY BRANCH_ID REFERENCES branches(branch_id);  -- filallar uzre constr qoyuldu


SELECT * FROM customers FOR UPDATE;   -- customers for update oldu



CREATE TABLE branches (BRANCH_İD NUMBER,
                       BRANCH_DESCR VARCHAR2(300));
                       
SELECT * FROM  branches FOR UPDATE;     -- filallar for update oldu                
                       
                       

ALTER TABLE branches MODIFY BRANCH_İD PRIMARY KEY;

CREATE TABLE currency (curr_id VARCHAR2(3),
                       curr_code NUMBER);      --valyuta cedveli yaradildi

ALTER TABLE currency MODIFY curr_code PRIMARY KEY;   -- primary key qoyuldu

SELECT * FROM currency FOR UPDATE ;  --valyuta for update oldu

CREATE TABLE exchange_rate (ex_rt_hstry DATE,
                            curr_code NUMBER,      --mezenne cedveli yaradildi
                            ex_rt NUMBER);
                            
 DROP TABLE                            
                            
SELECT * FROM EXCHANGE_rate FOR UPDATE; --mezenne ucun for update                          
                                                     
ALTER TABLE exchange_rate MODIFY curr_code REFERENCES currency(curr_code);  --referans verildi

CREATE TABLE Transfers (cif NUMBER REFERENCES customers(CUSTOMER_NO),   -- customer and curr cedv
                        Trnsfr_Amnt NUMBER,
                        ccy NUMBER REFERENCES currency(curr_code),
                        TRN_DT DATE);
                        
SELECT * FROM Transfers for UPDATE ; --tranzaksiya for update oldu

---------------------------------------------------


CREATE INDEX e_r_history_index ON exchange_rate (ex_rt_hstry); -- exchange_rate index yaradildi (tarix)
CREATE INDEX t_trn_dt_index ON Transfers (TRN_DT); -- Transfers index yaradildi (tarix)

CREATE BITMAP INDEX branch_customer
ON customers(BRANCH_ID);              -- bitmap index


---------------------------------------------------

CREATE OR REPLACE PACKAGE project_package                               -- PACKAGE yaradildi
 IS
  PROCEDURE Update_Customer_Tr(CUSTOMER_NO IN customers.customer_no%TYPE);
  PROCEDURE Update_Customer_Tr(p_customer_id transfers.cif%TYPE,
                               p_trn_date    transfers.trn_dt%TYPE);
  FUNCTION f_EXCHANGE_rate(f_ex_rt_hstry EXCHANGE_rate.Ex_Rt_Hstry%TYPE,
                           f_curr_code   EXCHANGE_rate.Curr_Code%TYPE)
    RETURN EXCHANGE_rate.Ex_Rt%TYPE;
END;
                        


CREATE OR REPLACE PACKAGE BODY project_package IS
                                                                           --PACKAGE body yaradildi
  PROCEDURE Update_Customer_Tr(CUSTOMER_NO IN customers.customer_no%TYPE) IS
  BEGIN
    UPDATE Transfers t
       SET t.trnsfr_amnt = t.trnsfr_amnt + 1.1
     WHERE t.cif = CUSTOMER_NO;
  END;
  PROCEDURE Update_Customer_Tr(p_customer_id transfers.cif%TYPE,
                               p_trn_date    transfers.trn_dt%TYPE) IS
    TYPE trnsf_dt_array IS TABLE OF transfers.trn_dt%TYPE INDEX BY PLS_INTEGER;
    p_trnsf_dt trnsf_dt_array;
  BEGIN
    SELECT t.trn_dt
      BULK COLLECT
      INTO p_trnsf_dt
      FROM transfers t
     WHERE t.cif = p_customer_id;
  
    FOR i IN p_trnsf_dt.first .. p_trnsf_dt.last LOOP
      IF p_trnsf_dt(i) < p_trn_date THEN
        UPDATE transfers t
           SET t.trnsfr_amnt =
               (SELECT MAX(t.trnsfr_amnt) FROM transfers t) * 0.2 +
               t.trnsfr_amnt
         WHERE t.cif = p_customer_id
           AND t.trn_dt = p_trnsf_dt(i);
      ELSE
        UPDATE transfers t
           SET t.trnsfr_amnt =
               (SELECT MIN(t.trnsfr_amnt) FROM transfers t) * 0.2 +
               t.trnsfr_amnt
         WHERE t.cif = p_customer_id
           AND t.trn_dt = p_trnsf_dt(i);
      END IF;
    END LOOP;
  END;
  FUNCTION f_EXCHANGE_rate(f_ex_rt_hstry EXCHANGE_rate.Ex_Rt_Hstry%TYPE,
                           f_curr_code   EXCHANGE_rate.Curr_Code%TYPE)
    RETURN EXCHANGE_rate.Ex_Rt%TYPE IS
    f_RESULT EXCHANGE_rate.Ex_Rt%TYPE;
    b        EXCEPTION;
    PRAGMA EXCEPTION_INIT(b, -20000);
  BEGIN
    BEGIN
      SELECT e.ex_rt
        INTO f_RESULT
        FROM EXCHANGE_rate e
       WHERE e.ex_rt_hstry = f_ex_rt_hstry
         AND e.curr_code = f_curr_code;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        dbms_output.put_line('Data not found !');
        f_RESULT := NULL;
        IF f_RESULT IS NULL THEN
          raise_application_error(-20000, 'Error found !');
        END IF;
    END;
    RETURN f_RESULT;
  END;
END;



BEGIN         -- yoxlanis
  project_package.Update_Customer_Tr(p_customer_id => 9758573,p_trn_date =>'13.jan.2023');
  END;

BEGIN 
  project_package.Update_Customer_Tr(CUSTOMER_NO =>9758573) ;
  END;
  
BEGIN 
  dbms_output.put_line(project_package.f_EXCHANGE_rate(f_ex_rt_hstry => SYSDATE, f_curr_code =>944));
  END;  

---------------------------------------------------------------------------------------------
/*Forma 1:*/

SELECT
c.customer_type,
SUM(CASE WHEN c.branch_id IN (0, 1, 3) THEN c.limit * f_EXCHANGE_rate('24.Feb.2019', c.limit_ccy)ELSE 0 END) 
AS "Limit Sum (Baki)",
SUM(CASE WHEN c.branch_id IN (0, 1, 3) THEN t.trnsfr_amnt * f_EXCHANGE_rate('24.Feb.2019', t.ccy)ELSE 0 END) 
AS "Transfer Sum (Baki)",
SUM(CASE WHEN c.branch_id = 2 THEN c.limit * f_EXCHANGE_rate('24.Feb.2019', c.limit_ccy) ELSE 0 END)
AS "Limit Sum (Sumqayit)",
SUM(CASE WHEN c.branch_id = 2 THEN t.trnsfr_amnt * f_EXCHANGE_rate('24.Feb.2019', t.ccy) ELSE 0 END) 
AS "Transfer Sum (Sumqayit)",
SUM(CASE WHEN c.branch_id = 4 THEN c.limit * f_EXCHANGE_rate('24.Feb.2019', c.limit_ccy) ELSE 0 END) 
AS "Limit Sum (Mingecevir)",
SUM(CASE WHEN c.branch_id = 4 THEN t.trnsfr_amnt * f_EXCHANGE_rate('24.Feb.2019', t.ccy) ELSE 0 END) 
AS "Transfer Sum (Mingecevir)"
FROM transfers t
INNER JOIN
    customers c ON c.customer_no = t.cif
GROUP BY
    c.customer_type;

-----------------------------------------------------------------------------


/*Forma 2:*/

SELECT
c.customer_type AS "Customer Type",
SUM(CASE WHEN NVL2(c.country,c.country,'AZ')='AZ' THEN TRUNC(c.limit * f_EXCHANGE_rate('01.Mar.2019', c.limit_ccy) / 1000, 1) ELSE 0 END)
AS "Azerbaijan Amount (in 1000)",
SUM(CASE WHEN c.country = 'RU' THEN TRUNC(c.limit * f_EXCHANGE_rate('01.Mar.2019', c.limit_ccy) / 1000, 1)ELSE 0 END) 
AS "Russia Amount (in 1000)",   
SUM(CASE WHEN c.country = 'TYR' THEN TRUNC(c.limit * f_EXCHANGE_rate('01.Mar.2019', c.limit_ccy) / 1000, 1) ELSE 0 END) 
AS "Turkey Amount (in 1000)",
SUM(CASE WHEN NVL2(c.country,c.country,'AZ')='AZ'  THEN 1 ELSE 0 END) AS "Azerbaijan Count",
SUM(CASE WHEN c.country = 'RU' THEN 1 ELSE 0 END) AS "Russia Count",
SUM(CASE WHEN c.country = 'TYR' THEN 1 ELSE 0 END) AS "Turkey Count"       
FROM customers c
GROUP BY c.customer_type;



                    -- War is over✌️

