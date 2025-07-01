USE [ILS]
GO

/****** Object:  StoredProcedure [dbo].[EXP_ConfirmationRfHtmlOverride]    Script Date: 01/07/2025 10:18:45 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




 
/*
 Mod		 | Programmer		| Date       | Modification Description
 --------------------------------------------------------------------
             | McDonald.Kgare	| 2/19/2014  | Stored Procedure for exit point:Confirmation RF HTML Override
             | RB				| 24/3/2023  | Add SD Group Picking Logic
			 | MK				| 08112023|  CHANGE - ADD text on RF Picking for Prod replacements 10279
			 | MK				| 29122023|  Container counter for dock management work
			 | MK				| 06032024|  Remove qc for rework console display custom
			 | PJVR				| 17032025|	 Hide Pass and View Picks Buttons for any SD Group Picking Work Instruction 
			 | MK				| 06032024|   Remove qc for rework console display custom
			 | MK				| 17062025|  #13341 Replenishment putaway sequence
			 | MK				| 23062025|  #1049 Mezzanine cage assignment + remove tote build from PND
*/
ALTER      PROCEDURE [dbo].[EXP_ConfirmationRfHtmlOverride] (
    @SESSIONVALUE xml,
    @html nvarchar(max) output,
    @workUnit nvarchar(max),
    @internalNum nvarchar(max),
    @item nvarchar(max),
    @company nvarchar(max),
    @quantity nvarchar(max),
    @location nvarchar(max),
    @lot nvarchar(max),
    @containerId nvarchar(max),
    @specialInfoDS nvarchar(max)
)
AS 
    SET NOCOUNT ON; 

	--what does myHtml Look Like before I change it
	--insert into HTML_DATAS values(@html)
 --05122024 remove test user
 if exists   ( select top 1  1 from user_profile where       (cast(@SESSIONVALUE as nvarchar(max)) like '%mike-scj%')     
	)
		
		begin
	exec 	[EXP_ConfirmationRfHtmlOverrideUserProc]
    @SESSIONVALUE  ,
    @html   output,
    @workUnit ,
    @internalNum  ,
    @item  ,
    @company  ,
    @quantity  ,
    @location ,
    @lot  ,
    @containerId  ,
    @specialInfoDS  
		end;
		 else 
		

	DECLARE @CONTAINER_TYPES TABLE (
	CONT NVARCHAR (50),
	NUM INT)

	INSERT INTO @CONTAINER_TYPES (CONT,NUM)
	SELECT CONTAINER_TYPE,COUNT(CONTAINER_TYPE)  AS NUM 
	FROM SHIPPING_CONTAINER (NOLOCK)
	WHERE INTERNAL_CONTAINER_NUM IN 
	(SELECT DISTINCT PARENT_CONTAINER_NUM FROM WORK_INSTRUCTION (NOLOCK) WHERE WORK_UNIT = @workUnit AND PARENT_CONTAINER_ID IS NOT NULL)
	GROUP BY CONTAINER_TYPE

	DECLARE @TROLLY_BUILD NVARCHAR (200) = (SELECT top 1 STRING_AGG(CONT + ': ' + CAST(NUM AS NVARCHAR), ', ')  FROM @CONTAINER_TYPES)
	DECLARE @CONTAINER_TYPE NVARCHAR (50) = (select top 1 CONTAINER_TYPE from SHIPPING_CONTAINER where CONTAINER_ID = @containerId)
	DECLARE @WORK_TYPE NVARCHAR(25) = (SELECT top 1 WORK_TYPE FROM WORK_INSTRUCTION (NOLOCK) WHERE WORK_UNIT = @workUnit)

	DECLARE @LAUNCHNUM numeric(9,0) = (SELECT top 1 LAUNCH_NUM FROM WORK_INSTRUCTION (NOLOCK) WHERE WORK_UNIT = @workUnit)
 
 
 
 -----Putawaysequence for replenishment
;WITH WorkInstructionData AS (
    SELECT 
        wi.INTERNAL_INSTRUCTION_NUM,
        wi.END_DATE_TIME,
        wi.WORK_UNIT,
        wi.TO_LOC,
        loc.PUTAWAY_SEQ,
        ROW_NUMBER() OVER (
            PARTITION BY wi.WORK_UNIT 
            ORDER BY ISNULL(loc.PUTAWAY_SEQ, wi.TO_LOC) DESC
        ) - 1 AS NEW_SEQUENCE
		,
        MAX(wi.END_DATE_TIME) OVER (PARTITION BY wi.WORK_UNIT) AS MAX_END_DATE_TIME
    FROM WORK_INSTRUCTION wi WITH (nolock)  
    LEFT JOIN LOCATION loc WITH (nolock) 
        ON loc.LOCATION = wi.TO_LOC 
        AND wi.TO_WHS = loc.WAREHOUSE
    WHERE wi.INSTRUCTION_TYPE = 'Detail'
        AND wi.WORK_GROUP = 'Replenishment'
        AND wi.WORK_UNIT = @workUnit
        AND wi.CONDITION <> 'Open'
),
PDLocations AS (
    SELECT LOCATION 
    FROM LOCATION WITH (nolock)
    WHERE LOCATION_CLASS = 'P&D' and active='Y'
)
UPDATE wi 
SET 
    wi.END_DATE_TIME = DATEADD(MILLISECOND, -ISNULL(wid.PUTAWAY_SEQ, 0), wid.MAX_END_DATE_TIME),
    wi.SEQUENCE = wid.NEW_SEQUENCE,
    wi.PROCESS_STAMP = 'ReplSeqStampCONF'
FROM WORK_INSTRUCTION wi
INNER JOIN WorkInstructionData wid 
    ON wi.INTERNAL_INSTRUCTION_NUM = wid.INTERNAL_INSTRUCTION_NUM
WHERE EXISTS (
    SELECT 1 FROM PDLocations pd 
    WHERE pd.LOCATION = @location
)

   -----Putawaysequence for replenishment
 


-----remove QC assignment
		IF (select count(*) from work_instruction wi where  WORK_UNIT = @workUnit and  condition<>'closed'and INSTRUCTION_TYPE='detail' and
					FROM_work_zone
					in ('W-CustomInventory','W-ReworkInventory','W-ConsoleInventory', 'W-DisplayInventory')	)>0

					begin 
					--set @html = REPLACE(@html,'<SPAN STYLE="font-weight:bold;color:#FF0000">**QC required**</SPAN>',
					--'<span style="font-weight:bold;color:#990011">PICKING FROM WORK STATION</SPAN>')
					
					update shc set shc.QC_ASSIGNMENT_ID=NULL , shc.QC_STATUS=NULL,
					shc.TRACKING_NUMBER =SH.order_type,
					shc.epc=isnull(sh.CONSOLIDATION_DOCK_LOC_AREA+'-'+sh.CONSOLIDATION_DOCK_LOC_POS, shc.location)
					,shc.user_def8=997
					from shipping_container shc
					left  join SHIPMENT_HEADER  sh on shc.INTERNAL_SHIPMENT_NUM=sh.internal_shipment_num
					where TREE_UNIT in (select TREE_UNIT from WORK_INSTRUCTION where WORK_UNIT=@workUnit and FROM_work_zone
					in ('W-CustomInventory','W-ReworkInventory','W-Consoleinventory','W-DisplayInventory') and condition<>'closed'and INSTRUCTION_TYPE='detail') 
					
    				SET @html = REPLACE(@html,'<Input  type="text" name="qtyEdit"','<Input  type="text" name="qtyEdit" value=0')
    				SET @html = REPLACE(@html,'<input type="button" value="Split"','<input type="button" style="background-color:red" value="Split"') 
					end

---remove QC assignment
if
	(SELECT COUNT(*)	FROM WORK_INSTRUCTION (NOLOCK)
											WHERE work_unit=@workunit and WORK_GROUP='Picking' 
											and condition<>'closed'
											AND INSTRUCTION_TYPE = 'Detail')>0

					begin 
					
					
					update shc set 
					shc.TRACKING_NUMBER =SH.order_type, shc.epc=isnull(sh.CONSOLIDATION_DOCK_LOC_AREA+'-'+sh.CONSOLIDATION_DOCK_LOC_POS, shc.location) from shipping_container shc
					left  join SHIPMENT_HEADER  sh on shc.INTERNAL_SHIPMENT_NUM=sh.internal_shipment_num
					where TREE_UNIT in (select TREE_UNIT from WORK_INSTRUCTION where WORK_UNIT=@workUnit and FROM_work_zone
					not in ('W-CustomInventory','W-ReworkInventory','W-Consoleinventory','W-DisplayInventory') 
					and condition<>'closed'and INSTRUCTION_TYPE='detail') 
						
					end


	DECLARE @GroupNumber AS VARCHAR(MAX) = (SELECT TOP 1 GROUP_NUM FROM WORK_INSTRUCTION (NOLOCK) WHERE INTERNAL_NUM = @internalNum)
	DECLARE @EndStartPos AS BIGINT = PATINDEX('%<Input  type=text name=TRANSCONTID %',@html) - 1
	DECLARE @BeginEndPos AS BIGINT = PATINDEX('%<input type="submit" value="OK" ID="bOK" name="bOK">%',@html)
	DECLARE @NewSection AS NVARCHAR(1000) = ('<Input  type=text name=TRANSCONTID onfocus="this.select();" size="25" maxlength="25.0"> </td></tr>

<tr>
	<td colspan=2>
')

--select * from AAA_TEST 
--ADD CONTAINER NUMBER AND TOTAL TO DOCK MANAGEMENT WORK /*231204*/


	
	IF ((SELECT PATINDEX('%<H3>Pick confirmation</H3>%',@html)) > 0 AND 
	(SELECT COUNT(*)
											FROM WORK_INSTRUCTION (NOLOCK)
											WHERE work_unit=@workunit and WORK_GROUP='Dock Management' and condition<>'closed' AND INSTRUCTION_TYPE = 'Detail')>0
											)
BEGIN
		DECLARE @CONT_ID NVARCHAR(25) = (SELECT TOP 1 CASE WHEN CONTAINER_ID = TREE_UNIT_ID THEN CONTAINER_ID ELSE TREE_UNIT_ID END AS CONT_ID 
											FROM WORK_INSTRUCTION (NOLOCK)
											WHERE WORK_GROUP='Dock Management' AND INSTRUCTION_TYPE = 'Detail'
											AND CONTAINER_ID = @containerId)

		DECLARE @CONT_NBR NVARCHAR(25) =(SELECT 
		 count(distinct tree_unit_id) from work_instruction where work_unit=@workunit
		and parent_instr in (select parent_instr from work_instruction where condition='in process') and FROM_QTY=0 ) 
		DECLARE @CONT_TTL NVARCHAR(25) = (SELECT 
		 count(distinct tree_unit_id) from work_instruction_view where work_unit=@workunit
		 and  parent_instr in (select parent_instr from work_instruction where condition='in process'))
		declare @custname nvarchar (25) =(select distinct  sh.customer_name from shipment_header sh  left join work_instruction wi on sh.internal_shipment_num=wi.internal_num
		where wi.WORK_UNIT=@workUnit and condition<>'closed')
	

		SET @html = REPLACE(@html,'<H3>Pick confirmation</H3>',
		'<H3>Pick confirmation</H3>'+'<SPAN STYLE="font-weight:bold;color:ORANGE"> Customer: '+@custname+'</SPAN> <br> '
									+'<SPAN STYLE="font-weight:bold;color:#FF0000"> Boxes: '+@CONT_NBR+' OF '+@CONT_TTL+'</SPAN> <br> ')


		END

--ADD CONTAINER NUMBER AND TOTAL TO DOCK MANAGEMENT WORK /*231204*/
	IF @EndStartPos > 1 AND @WORK_TYPE != 'SD Group Picking'
		BEGIN
			DECLARE @StartString AS NVARCHAR(MAX) = SUBSTRING(@html,1, @EndStartPos)
			IF @BeginEndPos > @EndStartPos
				BEGIN
					DECLARE @EndString AS NVARCHAR(MAX) = SUBSTRING(@html, @BeginEndPos, len(@html))	
					IF @GroupNumber IS NULL
						BEGIN
							SET @html = CONCAT(@StartString, @NewSection, @EndString)
						END
				END
		END
---PRODREPLACE HIGH PRIORITY PICKING
		
		IF (SELECT PATINDEX('%<H3>Pick confirmation</H3>%',@html)) >0 
					AND @location != 'CNV-IN-00'
					AND (@WORK_TYPE = 'Group Picking' or  @WORK_TYPE = 'Case Picking'  or @WORK_TYPE = 'SD Group Picking')
					AND ( select count(*)from shipment_header 
					where ORDER_TYPE='PRODREPLACE' and shipment_id in (select reference_id from WORK_INSTRUCTION where WORK_UNIT=@workUnit))>0
		BEGIN    
			set @html = REPLACE(@html,'<SPAN STYLE="font-weight:bold;color:#FF0000">**QC required**</SPAN>',
			'<span style="font-weight:bold;color:#990011">!URGENT ORDER!</span><br><SPAN STYLE="font-weight:bold;color:#FF0000">**QC required**</SPAN>');
		END


---SD GROUP PICKING

	IF (SELECT PATINDEX('%<H3>Pick confirmation</H3>%',@html)) >0 AND @WORK_TYPE = 'SD Group Picking' 
	AND @location != 'CNV-IN-00' and @location!='CNV-IN-EMB' and @location!='PND-IN-EMB' and @location not like '%cage%'
	
	BEGIN 
	

--FORMAT TOTE BUILD INFO
	SELECT stuff(@html,PATINDEX('%'+@CONTAINER_TYPE+'%',@html),LEN(@CONTAINER_TYPE),'<span style="font-weight:bold;color:BLUE">'+@CONTAINER_TYPE+'</span>')
	set @html = REPLACE(@html,'<SPAN STYLE="font-weight:bold;color:#FF0000">**QC required**</SPAN>','<SPAN STYLE="font-weight:bold;color:#FF0000">**QC required**</SPAN> <br> <span style="font-weight:bold;color:ORANGE">Build Tote Trolley</span> <br><span style="font-weight:bold;color:BLUE">'+@TROLLY_BUILD+'</span>')
	--FOR FIRST WORK UNIT		
	IF (@containerId LIKE '00004%'
	and 
	(select top 1 quantity_um from WORK_INSTRUCTION where container_id=@containerId and quantity_um is not null)<>'CS')
		BEGIN
		--CLEAR DEFAULT TOTE id
		SET @html = REPLACE(@html,'<Input  type="text" name="TRANSCONTID" value="' + @containerId +'"','<Input  type="text" name="TRANSCONTID"')
		--TOTE VALIDATION FUNCTION
			DECLARE @ScriptStartEndC AS BIGINT = (PATINDEX('%function validateContainer()%',@html) - 1)
			DECLARE @ScriptEndBeginC AS BIGINT = (PATINDEX('%function prepareHistory()%',@html) - 1)
			DECLARE @ScriptLenC AS INT = (SELECT @ScriptEndBeginC - @ScriptStartEndC)
			DECLARE @NewFuncC NVARCHAR(MAX) = (Select 'function validateContainer() {
			var numericValue = FORM1.qtyEdit.value;
			numericValue = numericValue.replace(/[ ]/g,"");
			numericValue = numericValue.replace(/[ ]/g,"");
			numericValue = numericValue.replace(",",".");
			document.FORM1.TRANSCONTID.value = trim(document.FORM1.TRANSCONTID.value.toUpperCase());

			var containerId = document.FORM1.TRANSCONTID.value;
			var prefix = containerId.substring(0, 3);
			var noncprefix = containerId.substring(0, 4);
			var numericSuffix = containerId.substring(3);


				if (numericValue > 0 && document.FORM1.TRANSCONTID.value == "") 
				{
					alert("Invalid Tote ID. Rescan");
					document.FORM1.TRANSCONTID.focus();
					return false;
				}

			if (numericValue > 0 && document.FORM1.TRANSCONTID.value !== "") 
			{
		
				if (prefix !== "SML" && prefix !== "MED" && prefix !== "LRG" && prefix !== "XLG" && noncprefix !== "NONC")
				{
					alert("Invalid Tote ID. Rescan");
					document.FORM1.TRANSCONTID.focus();
					return false;
				} else if (!/^[0-9]{4}$/.test(numericSuffix)) 
				{
					alert("Invalid Tote ID. Rescan");
					document.FORM1.TRANSCONTID.focus();
					return false;
				} else 

				{
					return true;
				}
			}
			return true;
		}')

		SET @html = (SELECT STUFF(@html, @ScriptStartEndC, @ScriptLenC, @NewFuncC))
			----HIDE PASS BUTTON FOR SEQUENCE GREATER THAN ZERO
			--IF (SELECT MIN(SEQUENCE) FROM WORK_INSTRUCTION WHERE WORK_UNIT = @workUnit AND INSTRUCTION_TYPE = 'Detail' AND CONTAINER_ID = @containerId) > 0
			--2025/03/17 -- HIDE PASS AND VIEW PICKS FOR ANY SD GROUP PICKING WORK INSTRUCTION 
			IF (SELECT MIN(SEQUENCE) FROM WORK_INSTRUCTION WHERE WORK_UNIT = @workUnit AND INSTRUCTION_TYPE = 'Detail' AND CONTAINER_ID = @containerId) >= 0
			BEGIN
			SET @html = REPLACE(@html,'<input type="Button" value="Pass"','<input type="Hidden" value="Pass"')
			--HIDE FULL BUTTON 
			SET @html = REPLACE(@html,'<input type="Button" value="Full"','<input type="Hidden" value="Full"')
			--HIDE VIEW PICKS BUTTON 
			SET @html = REPLACE(@html,'<input type="Button" value="View picks"','<input type="Hidden" value="View picks"')
			END
		END
	
	ELSE 
	BEGIN
	--HIDE SET TOTE ID
	SET @html = REPLACE(@html, '<Input  type="text" name="TRANSCONTID"', '<Input  type="hidden" name="TRANSCONTID"')
	-- CREATE NEW SCAN FIELD FOR VLAIDATION
	SET @html = REPLACE(@html, ' onfocus="this.select();" size="25" maxlength="25,0"',
		'> <Input type="text" name="NEWTRANSCONTID" onfocus="this.select();" size="25" maxlength="25"')	
	SET @html = REPLACE(@html, ' onfocus="this.select();" size="25" maxlength="25.0"',
						'> <Input type="text" name="NEWTRANSCONTID" onfocus="this.select();" size="25" maxlength="25"')
	--FUNCTION FOR VLAIDATING THE SAME TOTE IS BEING SCANNED
	DECLARE @ScriptStartEndB AS BIGINT = (PATINDEX('%function validateContainer()%',@html) - 1)
	DECLARE @ScriptEndBeginB AS BIGINT = (PATINDEX('%function prepareHistory()%',@html) - 1)
	DECLARE @ScriptLenB AS INT = (SELECT @ScriptEndBeginB - @ScriptStartEndB)
	DECLARE @NewFuncB NVARCHAR(MAX) = (Select 'function validateContainer() {
		var numericValue = FORM1.qtyEdit.value;numericValue = numericValue.replace(/[ ]/g,"");numericValue = numericValue.replace(/[ ]/g,"");numericValue = numericValue.replace(",",".");	document.FORM1.NEWTRANSCONTID.value = trim(document.FORM1.NEWTRANSCONTID.value.toUpperCase());

		if( numericValue > 0 && document.FORM1.NEWTRANSCONTID.value != document.FORM1.TRANSCONTID.value)
		{
			alert("Invalid Container ID.");
			document.FORM1.NEWTRANSCONTID.focus();
			return false;
		}
			return true;
	}')
							
	SET @html = (SELECT STUFF(@html, @ScriptStartEndB, @ScriptLenB, @NewFuncB))
		----HIDE PASS BUTTON FOR SEQUENCE GREATER THAN ZERO
		--IF (SELECT MIN(SEQUENCE) FROM WORK_INSTRUCTION WHERE WORK_UNIT = @workUnit AND INSTRUCTION_TYPE = 'Detail' AND CONTAINER_ID = @containerId) > 0
		--2025/03/17 -- HIDE PASS AND VIEW PICKS FOR ANY SD GROUP PICKING WORK INSTRUCTION 
		IF (SELECT MIN(SEQUENCE) FROM WORK_INSTRUCTION WHERE WORK_UNIT = @workUnit AND INSTRUCTION_TYPE = 'Detail' AND CONTAINER_ID = @containerId) >= 0
		BEGIN
		SET @html = REPLACE(@html,'<input type="Button" value="Pass"','<input type="Hidden" value="Pass"')
		--HIDE FULL BUTTON 
		SET @html = REPLACE(@html,'<input type="Button" value="Full"','<input type="Hidden" value="Full"')
		--HIDE VIEW PICKS BUTTON 
		SET @html = REPLACE(@html,'<input type="Button" value="View picks"','<input type="Hidden" value="View picks"')
		END
	END 
	END

-- HIDE BUTTONS FOR PUTAWAY CONFIRMATION ON PICKING
IF (SELECT PATINDEX('%<h3>Putaway confirmation</h3>%',@html)) >0 
AND @WORK_TYPE in ( 'SD Group Picking', 'Group Picking','Case Picking','Full Pallet Picking') 
AND ( @location = 'CNV-IN-00' or @location = 'CNV-IN-EMB' or @location = 'PND-IN-EMB' or @location='PCK-01')
BEGIN  
SET @html = REPLACE(@html,'<input type="Button" value="Pass"','<input type="Hidden" value="Pass"')
SET @html = REPLACE(@html,'<input type="Button" value="Skip"','<input type="Hidden" value="Skip"')
SET @html = REPLACE(@html,'<input type="Button" value="Override location"','<input type="Hidden" value="Override location"')
END 
 --HIDE BUTTONS FOR PUTAWAY CONFIRMATION ON PICKING
IF (SELECT PATINDEX('%<h3>Putaway confirmation</h3>%',@html)) >0 AND @WORK_TYPE in ( 'SD Group Picking', 'Group Picking') 
AND @location = 'UNDEF'
BEGIN  
SET @html = REPLACE(@html,'<input type="Button" value="Pass"','<input type="Hidden" value="Pass"')
SET @html = REPLACE(@html,'<input type="Button" value="Skip"','<input type="Hidden" value="Skip"')
SET @html = REPLACE(@html,'<input type="submit" value="OK"','<input type="Hidden" value="OK"')
--SET @html = REPLACE(@html,'<input type="submit" value="OK" id="ok" name="ok" autofocus','<input type="submit" value="OK" id="ok" name="ok"')
SET @html = REPLACE(@html,'<input type="Button" value="Bypass"','<input type="Hidden" value="Bypass"')
SET @html = REPLACE(@html,
    'value="Override location"',
    'value="Cage Assignment"') 
SET @html = REPLACE(@html,
    'value="Cage Assignment" id="overrideButton" name="overrideButton" onclick="overrideClick()">',
    'value="Cage Assignment" id="overrideButton" name="overrideButton" onclick="overrideClick()">
    <script>setTimeout(function(){document.getElementById("overrideButton").focus();}, 50);</script>')
END 
GO

