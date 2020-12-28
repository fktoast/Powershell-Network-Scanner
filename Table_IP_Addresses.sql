USE [Automation]
GO

/****** Object:  Table [dbo].[IP_Addresses]    Script Date: 12/28/2020 10:42:26 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[IP_Addresses](
	[PrimaryKey] [int] IDENTITY(1,1) NOT NULL,
	[IP_Address] [varchar](18) NOT NULL,
	[IP_Type] [varchar](50) NOT NULL,
	[IP_TTL] [int] NOT NULL,
	[IP_Latency] [int] NOT NULL,
	[IP_Hostname] [varchar](50) NOT NULL,
	[IP_Physical] [varchar](50) NOT NULL,
	[IP_Activity_First] [datetime] NULL,
	[IP_Activity_Last] [datetime] NULL,
	[IP_Activity_Message] [varchar](400) NULL,
	[Created] [datetime] NOT NULL,
	[Updated] [datetime] NOT NULL,
 CONSTRAINT [PK_IP_Addresses] PRIMARY KEY CLUSTERED 
(
	[PrimaryKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[IP_Addresses] ADD  CONSTRAINT [DF_IP_Addresses_IP_Type]  DEFAULT ('') FOR [IP_Type]
GO

ALTER TABLE [dbo].[IP_Addresses] ADD  CONSTRAINT [DF_IP_Addresses_IP_TTL]  DEFAULT ((0)) FOR [IP_TTL]
GO

ALTER TABLE [dbo].[IP_Addresses] ADD  CONSTRAINT [DF_IP_Addresses_IP_Latency]  DEFAULT ((-1)) FOR [IP_Latency]
GO

ALTER TABLE [dbo].[IP_Addresses] ADD  CONSTRAINT [DF_IP_Addresses_IP_Hostname]  DEFAULT ('') FOR [IP_Hostname]
GO

ALTER TABLE [dbo].[IP_Addresses] ADD  CONSTRAINT [DF_IP_Addresses_IP_Physical]  DEFAULT ('') FOR [IP_Physical]
GO

ALTER TABLE [dbo].[IP_Addresses] ADD  CONSTRAINT [DF_IP_Addresses_IP_Activity_Message]  DEFAULT ('') FOR [IP_Activity_Message]
GO

ALTER TABLE [dbo].[IP_Addresses] ADD  CONSTRAINT [DF_IP_Addresses_Created]  DEFAULT (getdate()) FOR [Created]
GO


