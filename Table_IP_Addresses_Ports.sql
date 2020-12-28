USE [Automation]
GO

/****** Object:  Table [dbo].[IP_Addresses_Ports]    Script Date: 12/28/2020 10:42:47 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[IP_Addresses_Ports](
	[PrimaryKey] [int] IDENTITY(1,1) NOT NULL,
	[Port] [varchar](5) NULL,
	[Status] [varchar](10) NULL,
	[IP_Address_PrimaryKey] [int] NULL,
	[IP_Address] [varchar](18) NULL,
	[Created] [datetime] NULL,
	[Updated] [datetime] NULL,
 CONSTRAINT [PK_IP_Addresses_Ports] PRIMARY KEY CLUSTERED 
(
	[PrimaryKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[IP_Addresses_Ports] ADD  CONSTRAINT [DF_IP_Addresses_Ports_Created]  DEFAULT (getdate()) FOR [Created]
GO


