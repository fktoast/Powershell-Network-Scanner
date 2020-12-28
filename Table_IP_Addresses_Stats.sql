USE [Automation]
GO

/****** Object:  Table [dbo].[IP_Addresses_Stats]    Script Date: 12/28/2020 10:43:01 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[IP_Addresses_Stats](
	[PrimaryKey] [int] IDENTITY(1,1) NOT NULL,
	[Free] [int] NULL,
	[Used] [int] NULL,
	[Created] [datetime] NULL,
	[Updated] [datetime] NULL,
 CONSTRAINT [PK_IP_Addresses_Stats] PRIMARY KEY CLUSTERED 
(
	[PrimaryKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[IP_Addresses_Stats] ADD  CONSTRAINT [DF_IP_Addresses_Stats_Created]  DEFAULT (getdate()) FOR [Created]
GO


