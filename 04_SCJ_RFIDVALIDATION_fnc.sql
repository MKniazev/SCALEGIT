IF EXISTS (SELECT * FROM sys.objects WHERE type IN ('FN', 'TF') AND name = 'SCJ_RFID_VALIDATION_CHECK')
                 BEGIN
                 DROP function SCJ_RFID_VALIDATION_CHECK;
                 END
                 GO
/****** Object:  UserDefinedFunction [dbo].[SCJ_RFID_VALIDATION_CHECK]    Script Date: 5/15/2025 12:03:07 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






/*
	MOD NUMBER	| PROGRAMMER	| DATE   	| MODIFICATION DESCRIPTION
	--------------------------------------------------------------------
	RFID Implementation		| MikhailKnyazev			| 04/17/25	| CREATED.
	RFID Implementation		| MikhailKnyazev			| 05/15/25	| Modifed to validate company 
	 
	Type =1 - Item validation
	Type =2 - Receipt container validation
	Type =3 - Shipping container validation
	if at least one item not RFID --> RFID validation not required
*/	
CREATE    FUNCTION [dbo].[SCJ_RFID_VALIDATION_CHECK](@data nvarchar(max),@type numeric(1))
RETURNS nvarchar(50)
  BEGIN 
  
   DECLARE @VALIDATION nvarchar(50); 
   DECLARE @DATACOLUMN  TABLE  (dataColumn nvarchar(50))  
   
   insert into  @DATACOLUMN
      SELECT 
Split.a.value('.', 'nvarchar(25)') AS 'DataColumn'  
										FROM (
											SELECT 
												CAST('<M>' + REPLACE(D.dataItem, ',', '</M><M>') + '</M>' AS XML) AS xml_data  
											FROM ( SELECT @data AS DataItem)D
											) AS temp CROSS APPLY xml_data.nodes('/M') AS Split(a)  

   DECLARE @ItemsForValidation  TABLE  (Item nvarchar(50)
										   , company nvarchar(25) 
										   )  

   --this is for phase 2 of RFID 
   --if @type=1 --item list validaiton
   --begin 
   --insert into  @ItemsForValidation
   --select distinct dataColumn as item from @DATACOLUMN   
   --end;
   if @type=2 --receipt containers list
   begin 
    insert into  @ItemsForValidation
      SELECT distinct item,COMPANY from receipt_container with (nolock) where container_id in (select dataColumn from @DATACOLUMN) and container_id is not null and status<301
   end;
        if @type=3 --shipping containers list
   begin 
    insert into  @ItemsForValidation
      SELECT distinct item,company from shipping_container  with (nolock) 
	  where tree_unit in (select distinct tree_unit from shipping_container with (nolock) where  
	  container_id in (select dataColumn from @DATACOLUMN) and container_id is not null and status between 600 and 700)
   end  
 
 set @VALIDATION=(

 
select case when count(*)>0  then'RFID_VALIDATION_NOT_REQUIRED' else'RFID_VALIDATION_REQUIRED' end FROM item i WITH (NOLOCK)
       inner join  @ItemsForValidation ifv on i.ITEM=ifv.Item and i.COMPANY=ifv.company
		where (( i.COMPANY in ('MNS', 'MNS_NTI') 
        AND  not  EXISTS (
            SELECT 1
            FROM generic_config_detail gcd WITH (NOLOCK)
            WHERE gcd.identifier = i.department
            AND gcd.record_type = 'MNS_RFID_VALIDATION'
            AND gcd.USER1VALUE = 'Y'
        ))
		or
	  ( i.COMPANY in ('ASICS') 
        AND  not EXISTS (
            SELECT 1
            FROM generic_config_detail gcd WITH (NOLOCK)
            WHERE  gcd.identifier = i.department AND i.ITEM_CATEGORY10='RFID_REQUIRED'  and i.ITEM_CATEGORY10 is not null 
            AND gcd.record_type = 'ASICS_RFID_VALIDATION'
            AND gcd.USER1VALUE = 'Y'
        )
		)
		)
    
	)
	 
			 
    
  	RETURN @VALIDATION 
  end

GO