import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Category, ClubStatus } from '@prisma/client';
import {
  IsBoolean,
  IsEmail,
  IsEnum,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
  MinLength,
} from 'class-validator';
import { PaginationDto } from '../common/pagination';
export class ClubQuery extends PaginationDto {
  @ApiPropertyOptional({ enum: Category })
  @IsOptional()
  @IsEnum(Category)
  category?: Category;
  @ApiPropertyOptional({ enum: ClubStatus })
  @IsOptional()
  @IsEnum(ClubStatus)
  status?: ClubStatus;
}
export class CreateClubDto {
  @ApiProperty() @IsString() @MinLength(2) @MaxLength(120) name!: string;
  @ApiProperty()
  @IsString()
  @MinLength(10)
  @MaxLength(10000)
  description!: string;
  @ApiProperty({ enum: Category }) @IsEnum(Category) category!: Category;
  @ApiPropertyOptional()
  @IsOptional()
  @IsUrl({
    require_tld: false,
    protocols: ['https', 'http'],
    require_protocol: true,
  })
  @MaxLength(2048)
  logoUrl?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsEmail()
  @MaxLength(254)
  contactEmail?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsUrl({ protocols: ['https', 'http'], require_protocol: true })
  @MaxLength(2048)
  websiteUrl?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsUrl({ protocols: ['https', 'http'], require_protocol: true })
  @MaxLength(2048)
  socialUrl?: string;
}
export class UpdateClubDto extends PartialType(CreateClubDto) {}
export class ClubStatusDto {
  @ApiProperty({ enum: ClubStatus }) @IsEnum(ClubStatus) status!: ClubStatus;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  rejectionReason?: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() isFeatured?: boolean;
}
