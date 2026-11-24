import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional } from 'class-validator';
import { PaginationDto } from '../common/pagination';
export class RegistrationQuery extends PaginationDto {
  @ApiPropertyOptional({ enum: ['upcoming', 'completed', 'cancelled'] })
  @IsOptional()
  @IsEnum(['upcoming', 'completed', 'cancelled'])
  tab?: 'upcoming' | 'completed' | 'cancelled';
}
export class RegistrationUpdateDto {
  @ApiProperty({ enum: ['CONFIRMED', 'ATTENDED', 'CANCELLED'] })
  @IsEnum(['CONFIRMED', 'ATTENDED', 'CANCELLED'])
  status!: 'CONFIRMED' | 'ATTENDED' | 'CANCELLED';
}
