USE [ILS]
GO

/****** Object:  StoredProcedure [dbo].[EXP_RfPutawayAfter]    Script Date: 01/07/2025 10:15:06 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




     
/*    
 Mod     | Programmer    | Date       | Modification Description    
 --------------------------------------------------------------------    
             | User  | 7/21/2016  | Stored Procedure for exit point:RF Putaway - After    
    | AP    | 17/09/2020  | Updated stored proc to capture MRN numbers in outgoing/incoming PND    
    | RB    | 24/03/2023  | Add SD Group Picking Logic    
	| SCJ   | 31/08/2023  | Added logic to unassign work after putaway 
	| MK    | 26/06/2025  | #CR1046 WorkUnit changes 
*/    
    
CREATE  PROCEDURE [dbo].[EXP_RfPutawayAfter] (    
    @SESSIONVALUE xml,    
    @INTINSTRNUMSERARRAY nvarchar(max),    
    @RFSESSION nvarchar(max),    
    @BASEDS nvarchar(max),    
    @LCID nvarchar(max),    
    @BROWSERVER nvarchar(max),    
    @RETURNVALUE nvarchar(max) output    
)    
AS     
    SET NOCOUNT ON;     
    
 /** Bonded stock move In transit and cannot be reversed now **/    
 BEGIN     
  UPDATE SCJ_BONDED_STOCK_MOVE_INTERFACE    
  SET COMPLETED_DATE_TIME = GETUTCDATE()    
  FROM WORK_INSTRUCTION WI (nolock)    
  WHERE SCJ_BONDED_STOCK_MOVE_INTERFACE.WORK_UNIT = WI.WORK_UNIT     
   AND SCJ_BONDED_STOCK_MOVE_INTERFACE.LAUNCH_NUM = WI.LAUNCH_NUM    
   AND WI.CONDITION = 'In Process' AND SCJ_BONDED_STOCK_MOVE_INTERFACE.COMPLETED_DATE_TIME IS NULL;    
 END;    
    
	  	--INSERT INTO TEST_RFPUTAWAY values (@SESSIONVALUE,  
    --@INTINSTRNUMSERARRAY ,  
    --@RFSESSION,
    --@BASEDS,
    --@LCID,
    --@BROWSERVER)

 DECLARE @INBPND TABLE (    
  INCOMING_PD_LOC NVARCHAR(25)    
 )    
    
 DECLARE @IIN NUMERIC(9,0) = (SELECT CASE WHEN CHARINDEX(',',@INTINSTRNUMSERARRAY) > 0     
   THEN    
    CAST(RIGHT(@INTINSTRNUMSERARRAY,CHARINDEX(',',REVERSE(@INTINSTRNUMSERARRAY))-1) AS NUMERIC(9,0))    
   ELSE    
    CAST(@INTINSTRNUMSERARRAY AS NUMERIC(9,0))    
   END)    
    
 DECLARE @REPLENHEADER nvarchar(MAX) = (select TOP 1 PARENT_INSTR from work_instruction     
  where work_group = 'Replenishment'     
  and internal_instruction_num = @IIN)    
   

   -----Putawaysequence for replenishment
  declare @wu table (	work_unit nvarchar (50) null,	
						outgoing_pd_loc nvarchar (25) null)


 insert into @wu
 select top 1  work_unit, outgoing_pd_loc from WORK_INSTRUCTION with(nolock)
 where 1=1
 and WORK_TYPE in ('SD Group Picking','Group Picking')
 and CONDITION<>'Closed'
 and OUTGOING_PD_LOC like 'CAGE%'
 and INSTRUCTION_TYPE='Detail' 
 and INVENTORY_AT_PD='O'
 and work_unit is not null 
 and OUTGOING_PD_LOC  is not null
 AND work_unit = (
			SELECT TOP 1 work_unit 
			FROM work_instruction WITH (NOLOCK) 
			WHERE internal_instruction_num = @IIN
		)
 
IF   EXISTS (SELECT 1 FROM @wu)
begin 
 ---add tote in process some where 
 --1. Locked
 update wi 
 set locked='Y' 
 from WORK_INSTRUCTION wi with (rowlock) 
 where WORK_UNIT = (select  work_unit from @wu )
 --2. Delete work unit
	if (select count( distinct work_unit) from WORK_INSTRUCTION with(nolock) 
					where outgoing_pd_loc in (select outgoing_pd_loc from @wu)
					and INSTRUCTION_TYPE='Detail'
					)>=2   
		begin --4 update parent_instr
		update WORK_INSTRUCTION 
		set Parent_instr  = (
			select top 1 parent_instr from work_instruction with (nolock) 
													where CONDITION='In Process' 
														and INSTRUCTION_TYPE ='detail' 
														and WORK_UNIT like 'CAGE%' 
														and parent_instr is not null 
														and OUTGOING_PD_LOC =(select  outgoing_pd_loc from @wu ) 
							) 
	 	where WORK_UNIT= (select  work_unit from @wu )  and INSTRUCTION_TYPE ='detail' 
		
		delete from WORK_INSTRUCTION with (rowlock) where INSTRUCTION_TYPE ='Header' 
					and work_unit in (select  WORK_UNIT from @wu) and WORK_UNIT is not null
					and WORK_TYPE in ('SD Group Picking','Group Picking')
					and CONDITION='In Process' 
 		end

 --3. Work unit assignment
 update wi 
 set WORK_UNIT=wu.outgoing_pd_loc 
 from work_instruction  wi with (rowlock)
 inner  join @wu wu on wu.WORK_UNIT=wi.WORK_UNIT
 where  
 wi.WORK_TYPE in ('SD Group Picking','Group Picking')
 and wi.CONDITION<>'Closed'
 and wu.OUTGOING_PD_LOC like 'CAGE%'
 and wu.work_unit is not null;

  --4. update sequence

  WITH SequenceCTE AS (
    SELECT 
       internal_instruction_num, 
        (ROW_NUMBER() OVER(PARTITION BY work_unit ORDER BY date_time_stamp ASC) - 1) AS new_sequence
    FROM WORK_INSTRUCTION
    WHERE CONDITION = 'In Process' 
      AND WORK_UNIT LIKE 'CAGE%' 
      AND INSTRUCTION_TYPE = 'detail'
      AND OUTGOING_PD_LOC IN (SELECT OUTGOING_PD_LOC FROM @wu)
)
UPDATE wi
SET SEQUENCE = seq.new_sequence
FROM WORK_INSTRUCTION wi
INNER JOIN SequenceCTE seq ON wi.internal_instruction_num = seq.internal_instruction_num

   --5. unlock work 
 update wi set   wi.locked='N'
 from WORK_INSTRUCTION wi 
 where CONDITION='In Process' 
 and WORK_UNIT like 'CAGE%'  
 and OUTGOING_PD_LOC in (select OUTGOING_PD_LOC from @wu)
 END
 ---add tote in process some where 



----SD Group Picking---    
 DECLARE @STRING TABLE (STRING NVARCHAR(MAX))    
 DECLARE @INTERNAL_NUM TABLE (INT_INSTR_NUM NVARCHAR(MAX),CONTAINER_ID NVARCHAR(MAX) ,TREE_UNIT NVARCHAR(MAX),WORK_UNIT NVARCHAR(MAX),WORK_TYPE NVARCHAR(MAX),TO_LOC NVARCHAR(MAX), SC_LOC NVARCHAR(MAX), INTERNAL_CONTAINER_NUM NVARCHAR(MAX))  
    
 INSERT INTO @STRING    
 SELECT @INTINSTRNUMSERARRAY;    
 WITH INT_STRING AS (SELECT TRIM(value) AS VALUE FROM @STRING S    
 CROSS APPLY STRING_SPLIT(STRING, ','))    
    
 INSERT INTO @INTERNAL_NUM (INT_INSTR_NUM,CONTAINER_ID,TREE_UNIT,WORK_UNIT,WORK_TYPE,TO_LOC,SC_LOC,INTERNAL_CONTAINER_NUM)     
 SELECT S.VALUE,WIV.CONTAINER_ID,CAST (WIV.TREE_UNIT_ID AS NVARCHAR(MAX)),WIV.WORK_UNIT,WIV.WORK_TYPE,WIV.TO_LOC,SC.LOCATION,SC.INTERNAL_CONTAINER_NUM FROM INT_STRING S    
 INNER JOIN WORK_INSTRUCTION_VIEW WIV ON WIV.INTERNAL_INSTRUCTION_NUM = value    
 inner join SHIPPING_CONTAINER SC on WIV.INTERNAL_CONTAINER_NUM = SC.INTERNAL_CONTAINER_NUM 
     
 DECLARE @WORK_TYPE NVARCHAR(25) = (SELECT DISTINCT(WORK_TYPE) FROM @INTERNAL_NUM)    
    
    
 ---WCS UPDATE BARCODE TO CONTAINER ID---    
 IF (@WORK_TYPE = 'SD Group Picking')    
  BEGIN    
   UPDATE WCS    
   SET Barcode = I.CONTAINER_ID    
   FROM [WCS].DBO.ContainerInstruction WCS    
   INNER JOIN @INTERNAL_NUM I ON I.TREE_UNIT = WCS.Barcode AND I.WORK_UNIT = WCS.AssociationBarcode    
     
   update WORK_INSTRUCTION set USER_ASSIGNED=NULL where WORK_UNIT in (
   select INUM.WORK_UNIT from WORK_INSTRUCTION WI inner join @INTERNAL_NUM INUM on WI.INTERNAL_INSTRUCTION_NUM = INUM.INT_INSTR_NUM 
   and WI.INTERNAL_CONTAINER_NUM = INUM.INTERNAL_CONTAINER_NUM where INUM.SC_LOC like 'CNV%' and WI.USER_ASSIGNED IS NOT NULL and WI.CONDITION = 'In Process' )   
  
  END    
     
 ---CHECK AND DELETE BARCODE IN WCS IF IT EXISTS FROM SAMPLEBRANCH AND RED SLIPS---    
 IF (@WORK_TYPE = 'SD Group Picking') AND exists (select * from [WCS].DBO.ContainerInstruction where Barcode in (select container_id from @INTERNAL_NUM WHERE TO_LOC = 'CNV-IN-01')    
              AND AssociationBarcode NOT IN(select WORK_UNIT from @INTERNAL_NUM WHERE TO_LOC = 'CNV-IN-01'))    
  BEGIN    
      
  UPDATE [WCS].DBO.ContainerInstruction    
  SET Barcode = Barcode + 'Remove'    
  where Barcode in (select container_id from @INTERNAL_NUM WHERE TO_LOC = 'CNV-IN-01')    
  AND AssociationBarcode NOT IN(select WORK_UNIT from @INTERNAL_NUM WHERE TO_LOC = 'CNV-IN-01')    
           
  END    
 IF (@WORK_TYPE = 'SD Group Picking') AND exists (select top 1 LineId from [WCS].DBO.ContainerInstruction where Barcode in (select container_id from @INTERNAL_NUM)    
              AND AssociationBarcode NOT IN(select WORK_UNIT from @INTERNAL_NUM))    
  BEGIN    
      
  UPDATE [WCS].DBO.ContainerInstruction    
  SET Barcode = Barcode + 'Remove'    
  where Barcode in (select container_id from @INTERNAL_NUM)    
  AND AssociationBarcode NOT IN(select WORK_UNIT from @INTERNAL_NUM)    
           
  END    
    
    
    
    
    
GO

