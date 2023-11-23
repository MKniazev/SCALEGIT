USE ILS IF EXISTS (
SELECT  1
FROM sys.views
WHERE NAME = 'VIEW_SCJ_AMROD_SHC_STATUS'
AND type = 'V' ) DROP view dbo.VIEW_SCJ_AMROD_SHC_STATUS
GO 


USE [ILS]
GO

/****** Object:  View [dbo].[VIEW_SCJ_AMROD_SHC_STATUS]    Script Date: 17/11/2023 10:42:10 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[VIEW_SCJ_AMROD_SHC_STATUS]
AS
SELECT        sh.SHIPMENT_ID, sh.ERP_ORDER, ISNULL(shh.CONTAINER_ID, shcd.CONTAINER_ID) AS container_id, mop.MULTI_ORDER_PALLET_ID, ISNULL(shh.PARENT_CONTAINER_ID, shcd.PARENT_CONTAINER_ID) 
                         AS parent_container_id, shcd.INTERNAL_CONTAINER_NUM, shcd.LOCATION, shcd.status, shcd.ITEM, sd.ITEM_DESC, shcd.QUANTITY, shcd.QUANTITY_UM, sh.USER_DEF2 AS Blocked, 
                         shcd.TRACKING_NUMBER AS Container_Split, sd.ERP_ORDER AS Expr1, sd.ERP_ORDER_LINE_NUM, shcd.warehouse, shcd.COMPANY, sh.SHIPPING_LOAD_NUM, shcd.INTERNAL_SHIPMENT_NUM, sh.CARRIER, 
                         sh.CARRIER_SERVICE, sh.SHIP_TO_NAME, sh.SHIP_TO_ADDRESS1, sh.SHIP_TO_ADDRESS2, sh.SHIP_TO_ADDRESS3
FROM            dbo.SHIPPING_CONTAINER AS shcd INNER JOIN
                         dbo.SHIPPING_CONTAINER AS shh ON shh.TREE_UNIT = shcd.TREE_UNIT LEFT OUTER JOIN
                         dbo.SHIPMENT_HEADER AS sh ON shcd.INTERNAL_SHIPMENT_NUM = sh.INTERNAL_SHIPMENT_NUM LEFT OUTER JOIN
                         dbo.SHIPPING_LOAD AS sl ON sh.SHIPPING_LOAD_NUM = sl.INTERNAL_LOAD_NUM LEFT OUTER JOIN
                         dbo.MULTI_ORDER_PALLET AS mop ON shcd.INTERNAL_MOP_NUMBER = mop.INTERNAL_MOP_NUMBER LEFT OUTER JOIN
                         dbo.SHIPMENT_DETAIL AS sd ON shcd.ITEM = sd.ITEM AND shcd.COMPANY = sd.COMPANY AND sd.INTERNAL_SHIPMENT_LINE_NUM = shcd.INTERNAL_SHIPMENT_LINE_NUM
WHERE        (shcd.status >= 600) AND (shcd.status < 900) AND (shcd.ITEM IS NOT NULL) AND (shh.ITEM IS NULL)
GO

EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "shcd"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 342
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "shh"
            Begin Extent = 
               Top = 6
               Left = 380
               Bottom = 136
               Right = 684
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "sh"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 268
               Right = 320
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "sl"
            Begin Extent = 
               Top = 138
               Left = 358
               Bottom = 268
               Right = 635
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "mop"
            Begin Extent = 
               Top = 6
               Left = 722
               Bottom = 136
               Right = 951
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "sd"
            Begin Extent = 
               Top = 138
               Left = 673
               Bottom = 268
               Right = 954
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 117' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'VIEW_SCJ_AMROD_SHC_STATUS'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane2', @value=N'0
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'VIEW_SCJ_AMROD_SHC_STATUS'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=2 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'VIEW_SCJ_AMROD_SHC_STATUS'
GO


