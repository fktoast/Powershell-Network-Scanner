USE [Automation]
GO

/****** Object:  Table [dbo].[IP_Addresses_Ports_Stats]    Script Date: 12/28/2020 10:42:57 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[IP_Addresses_Ports_Stats](
	[PrimaryKey] [int] IDENTITY(1,1) NOT NULL,
	[Port] [int] NULL,
	[OpenCount] [int] NULL,
	[ClosedCount] [varchar](8) NULL,
	[Created] [datetime] NOT NULL,
	[Updated] [datetime] NULL,
 CONSTRAINT [PK_IP_Addresses_Ports_Stats] PRIMARY KEY CLUSTERED 
(
	[PrimaryKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[IP_Addresses_Ports_Stats] ADD  CONSTRAINT [DF_IP_Addresses_Ports_Stats_Created]  DEFAULT (getdate()) FOR [Created]
GO


